import 'dart:core';
import 'dart:core' as core;

import 'package:dev_test/test.dart';
import 'package:idb_shim/sdb.dart';
import 'package:path/path.dart';

Future<void> main() async {
  var factory = sdbFactoryMemory;
  sdbStressNotesGroup(factory);
}

void write(Object? msg) =>
    // ignore: avoid_print
    print(msg);

class StressNotesDb {
  final void Function(Object? object) _print;
  final SdbDatabase db;

  StressNotesDb({void Function(Object? object)? print, required this.db})
    : _print = print ?? core.print;

  static Future<StressNotesDb> open(SdbFactory factory, String name) async {
    var db = await factory.openDatabaseOnDowngradeDelete(
      name,
      options: dbOpenOptions,
    );
    return StressNotesDb(db: db);
  }

  static Future<void> createNAndList(
    SdbFactory factory, {
    String? dbName,
    int? count,
  }) async {
    count ??= 10;
    var notesDb = await StressNotesDb.open(
      factory,
      dbName ?? 'stress_notes.db',
    );
    await notesDb.generateNotes(count);
    await notesDb.dumpNotes();
    await notesDb.close();
  }

  Future<void> generateNotes(int count) async {
    for (var i = 0; i < count; i++) {
      await dbNoteStore.add(
        db,
        DbNote(
          timestamp: SdbTimestamp.now(),
          title: 'note $i',
          description: 'description ${i + 1}',
        ).toModel(),
      );
    }
    await dumpNotes(limit: 5);
    _print('Added $count notes');
  }

  Future<void> dumpNotes({int? limit}) async {
    var found = 0;
    var notes = await dbNoteStore.findRecords(
      db,
      options: SdbFindOptions(descending: true, limit: limit),
    );
    for (var note in notes) {
      _print('note: $note');
      if (++found >= 15) {
        break;
      }
    }
    _print(
      'found ${notes.length} notes${limit != null ? ', limit: $limit' : ''}, showing last $found',
    );
  }

  Future<void> close() async {
    await db.close();
  }
}

/// Record with an int key
class DbNote {
  final String? title;
  final String? description;
  final SdbTimestamp? timestamp;

  DbNote({this.title, this.description, this.timestamp});

  SdbModel toModel() {
    return SdbModel.from({
      'title': title,
      'description': description,
      'timestamp': timestamp,
    });
  }
}

final dbNoteStore = SdbStoreRef<int, SdbModel>('note');
final dbTimestampIndex = dbNoteStore.index<SdbTimestamp>('timestamp_index');
var dbSchema = SdbDatabaseSchema(
  stores: [
    dbNoteStore.schema(
      autoIncrement: true,
      indexes: [dbTimestampIndex.schema(keyPath: 'timestamp')],
    ),
  ],
);
final dbOpenOptions = SdbOpenDatabaseOptions(schema: dbSchema, version: 1);

extension DbNoteExt on SdbDatabase {
  DbNote modelToNote(SdbModel model) {
    return DbNote(
      title: model['title'] as String?,
      description: model['description'] as String?,
      timestamp: model['timestamp'] as SdbTimestamp?,
    );
  }

  Future<List<DbNote>> getNotes() async => (await dbNoteStore.findRecords(
    this,
  )).map((r) => modelToNote(r.value)).toList();
}

void sdbStressNotesGroup(SdbFactory sdbFactory, {String? path}) {
  String fixDbName(String? name) {
    name ??= 'stress_notes.db';
    if (path != null) {
      return join(path, name);
    }

    return name;
  }

  group('note manager', () {
    late SdbDatabase db;
    late StressNotesDb notesDb;
    Future<void> dbClose() async {
      await db.close();
      write('closed ${db.name}');
    }

    Future<void> dbOpen() async {
      var fullDbName = fixDbName('note_manager.db');
      db = await sdbFactory.openDatabaseOnDowngradeDelete(
        fullDbName,
        options: dbOpenOptions,
      );
      notesDb = StressNotesDb(db: db, print: (msg) => write(msg));
      write('opened $fullDbName');
    }

    setUpAll(() async {
      await dbOpen();
    });
    tearDownAll(() async {
      await dbClose();
    });
    test('db info', () async {
      write('db: $db');
      write('factory: ${db.factory}');
      write('name: ${db.name}');
      write('version: ${db.version}');
    });
    test('reopen', () async {
      await dbClose();
      await dbOpen();
    });
    test('dump_notes', () async {
      await notesDb.dumpNotes();
    });
    test('count', () async {
      write('count: ${await dbNoteStore.count(db)}');
    });

    test('dump_last_15', () async {
      await notesDb.dumpNotes(limit: 15);
    });

    test('add note', () async {
      await dbNoteStore.add(
        db,
        DbNote(timestamp: SdbTimestamp.now(), title: 'note 1').toModel(),
      );
      await notesDb.dumpNotes();
    });
  });
  group('open', () async {
    test('open downgrade', () async {
      var name = fixDbName('open_downgrade.db');
      await sdbFactory.deleteDatabase(name);
      var db = await sdbFactory.openDatabase(
        name,
        options: dbOpenOptions.copyWith(version: 2),
      );
      await db.close();
      try {
        db = await sdbFactory.openDatabase(name, options: dbOpenOptions);
        await db.close();
      } catch (e) {
        write('error type: ${e.runtimeType}');
        write('error: $e');
      }
    });
    test('openOnDowngradeDelete downgrade', () async {
      var name = fixDbName('sdb_openOnDowngradeDelete_downgrade.db');
      await sdbFactory.deleteDatabase(name);
      write('open version 2');
      var db = await sdbFactory.openDatabase(
        name,
        options: dbOpenOptions.copyWith(
          version: 2,
          onVersionChange: (SdbVersionChangeEvent e) async {
            var txn = e.transaction;
            await dbNoteStore.add(
              txn,
              DbNote(
                timestamp: SdbTimestamp.now(),
                title: 'note 2',
                description: 'description 2',
              ).toModel(),
            );
          },
        ),
      );
      Future<void> dumpRows() async {
        write('opened ${db.version}');
        var notes = await dbNoteStore.findRecords(db);

        for (var note in notes) {
          write('row: $note');
        }
        write('found ${notes.length} notes');
      }

      await dumpRows();
      await db.close();
      write('open version 1');
      try {
        db = await sdbFactory.openDatabaseOnDowngradeDelete(
          name,
          options: dbOpenOptions.copyWith(
            onVersionChange: (SdbVersionChangeEvent e) async {
              var txn = e.transaction;
              await dbNoteStore.add(
                txn,
                DbNote(
                  timestamp: SdbTimestamp.now(),
                  title: 'note 1',
                  description: 'description 1',
                ).toModel(),
              );
            },
          ),
        );
        await dumpRows();
        await db.close();
      } catch (e) {
        write('error type: ${e.runtimeType}');
        write('error: $e');
      }
    });
  });
}

void sdbStressAddListNotesGroup(
  SdbFactory factory, {
  String? path,
  String? dbName,
  List<int>? addedCount,
}) {
  var defaultDbName = dbName ?? 'stress_add.db';
  String fixDbName(String? name) {
    name ??= defaultDbName;
    if (path != null) {
      return join(path, name);
    }

    return name;
  }

  var fullDbName = fixDbName(null);
  Future<void> sdbCreateNAndList({int? count}) async {
    count ??= 10;
    await StressNotesDb.createNAndList(
      factory,
      dbName: fullDbName,
      count: count,
    );
  }

  for (var count in [10, ...?addedCount]) {
    final testCount = count;
    test(
      'create and list $testCount',
      () async {
        await sdbCreateNAndList(count: testCount);
      },
      timeout: Timeout(Duration(minutes: testCount > 500 ? 5 : 1)),
    );
  }

  // Solo?
  var count = 10;
  test(
    'create and list $count',
    () async {
      await sdbCreateNAndList(count: count);
    },
    //solo: true,
    timeout: Timeout(Duration(minutes: count > 500 ? 5 : 1)),
  );
}
