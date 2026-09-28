import 'dart:async';

import 'package:idb_shim/sdb.dart';
import 'package:web/web.dart' as web;

/// One database for every app (frame or tab) of the origin.
const dbName = 'sdb_version_change_exp.db';

/// The records added by the apps.
final recordStore = SdbStoreRef<int, SdbModel>('record');

/// The same schema whatever the version: the version number is what matters
/// here.
SdbDatabaseSchema get schema =>
    SdbDatabaseSchema(stores: [recordStore.schema(autoIncrement: true)]);

/// From the `app` query parameter (`app.html?app=A`).
late final String appName;

/// The open database, null when closed (by us, or on its own).
SdbDatabase? db;

final _title = web.document.querySelector('#title')!;
final _status = web.document.querySelector('#status')!;
final _input = web.document.querySelector('#input')!;
final _output = web.document.querySelector('#output')!;
final _versionChangeActionSelect =
    web.document.querySelector('#version_change_action')
        as web.HTMLSelectElement;
final _blockedActionSelect =
    web.document.querySelector('#blocked_action') as web.HTMLSelectElement;

/// The note left for the page reloaded on a version change.
const _reloadedKey = 'sdb_version_change_exp_reloaded';

var _lines = <String>[];

/// Log a line (the console too).
void write(String message) {
  var line = '${DateTime.now().toIso8601String().substring(11, 19)} $message';
  // ignore: avoid_print
  print('$appName: $line');
  _lines.add(line);
  if (_lines.length > 60) {
    _lines = _lines.sublist(_lines.length - 50);
  }
  _output.textContent = _lines.join('\n');
}

/// The banner over the buttons, hidden when null.
void setStatus(String? text) {
  _status.textContent = text ?? '';
  _status.classList.toggle('shown', text != null);
}

void addButton(String text, FutureOr<void> Function() action) {
  _input.append(
    (web.document.createElement('button') as web.HTMLButtonElement)
      ..textContent = text
      ..onClick.listen((event) async {
        await action();
      }),
  );
}

/// Close the database if open.
Future<void> closeDb() async {
  var current = db;
  if (current != null) {
    db = null;
    await current.close();
    write('closed');
  }
}

/// Open the database at [version].
Future<void> openVersion(int version) async {
  await closeDb();
  setStatus(null);
  // What the database does on its own, read when opening.
  var versionChangeAction = SdbVersionChangeAction.values.byName(
    _versionChangeActionSelect.value,
  );
  var blockedAction = SdbBlockedAction.values.byName(
    _blockedActionSelect.value,
  );
  write(
    'open version $version (${versionChangeAction.name} on version change,'
    ' ${blockedAction.name} when blocked)…',
  );
  var blocked = false;
  try {
    var opened = await sdbFactoryWeb.openDatabase(
      dbName,
      options: SdbOpenDatabaseOptions(
        version: version,
        schema: schema,
        versionChangeAction: versionChangeAction,
        onVersionChangeRequest: (event) {
          var newVersion = event.newVersion;
          write(
            newVersion == null
                ? 'another app deletes the database'
                : 'another app opens version $newVersion'
                      ' (this one has ${event.oldVersion})',
          );
          // The action happens right after this callback.
          switch (versionChangeAction) {
            case SdbVersionChangeAction.none:
              write(
                'not closing: the other app waits until Close is pressed here',
              );
            case SdbVersionChangeAction.close:
              db = null;
              write('closing: reload (or open again) to use the new version');
            case SdbVersionChangeAction.closeAndReload:
            case SdbVersionChangeAction.closeAlertAndReload:
              // The page reloads: leave a note for the reloaded one.
              web.window.sessionStorage.setItem(
                _reloadedKey,
                newVersion == null
                    ? 'another app deleted the database'
                    : 'another app opened version $newVersion',
              );
              write('closing and reloading…');
          }
        },
        blockedAction: blockedAction,
        onBlocked: (event) {
          blocked = true;
          write('blocked by another app, waiting…');
          // With the alert action, the library shows its message right after.
          if (blockedAction == SdbBlockedAction.none) {
            setStatus(
              'Blocked: another app (frame or tab) keeps ${event.name} open'
              ' at an older version and does not close on version change.'
              ' Press Close there.',
            );
          }
        },
      ),
    );
    setStatus(null);
    db = opened;
    write('opened version ${opened.version}${blocked ? ' (unblocked)' : ''}');
  } catch (e) {
    setStatus(null);
    write('open failed: $e');
  }
}

/// Add a record, to see the database is usable (or not).
Future<void> addRecord() async {
  var current = db;
  if (current == null) {
    write('no database open');
    return;
  }
  try {
    var key = await recordStore.add(current, {
      'app': appName,
      'at': DateTime.now().toIso8601String(),
    });
    var count = await recordStore.count(current);
    write('record $key added, $count records');
  } catch (e) {
    write('add failed${current.isClosed ? ' (closed)' : ''}: $e');
  }
}

/// Show the version and the record count.
Future<void> showState() async {
  var current = db;
  if (current == null) {
    write('no database open');
    return;
  }
  try {
    write(
      'version ${current.version}, ${await recordStore.count(current)}'
      ' records, isClosed ${current.isClosed}',
    );
  } catch (e) {
    write('read failed${current.isClosed ? ' (closed)' : ''}: $e');
  }
}

/// Delete the database: the other apps get a version change request too.
Future<void> deleteDb() async {
  await closeDb();
  write('delete…');
  await sdbFactoryWeb.deleteDatabase(dbName);
  write('deleted');
}

void main() {
  appName = Uri.parse(web.window.location.href).queryParameters['app'] ?? 'app';
  _title.textContent = 'App $appName';
  web.document.title = 'SDB app $appName';
  for (var version in [1, 2, 3]) {
    addButton('Open version $version', () => openVersion(version));
  }
  addButton('Add a record', addRecord);
  addButton('Show version and count', showState);
  addButton('Close', closeDb);
  addButton('Delete the database', deleteDb);
  var reloaded = web.window.sessionStorage.getItem(_reloadedKey);
  if (reloaded != null) {
    web.window.sessionStorage.removeItem(_reloadedKey);
    write('reloaded: $reloaded');
  }
  write('ready: open a version');
}
