import 'dart:async';

import 'package:idb_shim/idb_sdb.dart';

/// Event passed to [SdbOnVersionChangeCallback].
abstract class SdbVersionChangeEvent {
  /// Event passed to [SdbOnVersionChangeCallback].
  factory SdbVersionChangeEvent({
    required SdbOpenDatabase db,
    required SdbOpenTransaction transaction,
    required int oldVersion,
    required int newVersion,
  }) => SdbVersionChangeEventImpl(db, transaction, oldVersion, newVersion);

  /// The old version, 0 if new
  int get oldVersion;

  /// The new version.
  int get newVersion;

  /// The opened database.
  SdbOpenDatabase get db;

  /// The opened transaction
  SdbOpenTransaction get transaction;
}

/// Callback for [SdbFactory.openDatabase].
typedef SdbOnVersionChangeCallback =
    FutureOr<void> Function(SdbVersionChangeEvent event);

/// What another connection (another tab, an iframe, or this page) asks of an
/// open database: an open at a higher version, or a delete. Passed to
/// [SdbOpenDatabaseOptions.onVersionChangeRequest].
abstract class SdbVersionChangeRequestEvent {
  /// The open database the request is about.
  SdbDatabase get db;

  /// Its current version.
  int get oldVersion;

  /// The requested version, `null` when the database is being deleted.
  int? get newVersion;
}

/// Callback for [SdbOpenDatabaseOptions.onVersionChangeRequest].
typedef SdbOnVersionChangeRequestCallback =
    void Function(SdbVersionChangeRequestEvent event);

/// What a database does on its own when another connection (another tab, an
/// iframe, or this page) opens it at a higher version or deletes it, the
/// IndexedDB `versionchange` event, right after
/// [SdbOpenDatabaseOptions.onVersionChangeRequest].
///
/// Only the browser fires the event: io and memory databases never act.
enum SdbVersionChangeAction {
  /// Nothing: the database stays open and the other connection waits,
  /// blocked, until this one is closed by the app.
  none,

  /// Close the database (the default): the other connection proceeds, this
  /// one is unusable ([SdbDatabase.isClosed]), the app should reload or open
  /// again.
  close,

  /// Close the database then reload the page (web; close only elsewhere): the
  /// page comes back on the new version of the app.
  closeAndReload,

  /// Close the database, tell the user ([sdbVersionChangeReloadMessage], or
  /// [sdbVersionChangeDeleteReloadMessage] on a delete, a blocking alert)
  /// then reload the page (web; close only elsewhere).
  closeAlertAndReload,
}

/// What an open does on its own while blocked by another connection that
/// keeps the database open at a lower version, right after
/// [SdbOpenDatabaseOptions.onBlocked]. The open waits and completes once
/// that connection closes whatever the action.
enum SdbBlockedAction {
  /// Nothing, the open waits silently (the app tells the user in
  /// [SdbOpenDatabaseOptions.onBlocked]).
  none,

  /// Tell the user to close the other tabs ([sdbBlockedMessage], a blocking
  /// alert on the web, nothing elsewhere), the default.
  alert,
}

/// The message of [SdbVersionChangeAction.closeAlertAndReload] on a newer
/// version.
const sdbVersionChangeReloadMessage =
    'A newer version of this app opened in another tab or window.'
    ' This page reloads.';

/// The message of [SdbVersionChangeAction.closeAlertAndReload] on a delete.
const sdbVersionChangeDeleteReloadMessage =
    'The data of this app was reset from another tab or window.'
    ' This page reloads.';

/// The message of [SdbBlockedAction.alert].
const sdbBlockedMessage =
    'Another tab or window of this app keeps its data open at an older'
    ' version. Close it to continue.';

/// An open blocked by another connection that keeps the database open at a
/// lower version, see [SdbOpenDatabaseOptions.onBlocked].
abstract class SdbBlockedEvent {
  /// The database name.
  String get name;

  /// The version requested by the blocked open, `null` when none was given.
  int? get version;
}

/// Callback for [SdbOpenDatabaseOptions.onBlocked].
typedef SdbOnBlockedCallback = void Function(SdbBlockedEvent event);

/// Version change request implementation.
class SdbVersionChangeRequestEventImpl implements SdbVersionChangeRequestEvent {
  /// Version change request implementation.
  SdbVersionChangeRequestEventImpl({
    required this.db,
    required this.oldVersion,
    required this.newVersion,
  });
  @override
  final SdbDatabase db;
  @override
  final int oldVersion;
  @override
  final int? newVersion;

  @override
  String toString() =>
      'SdbVersionChangeRequestEvent(${db.name}, $oldVersion => ${newVersion ?? 'delete'})';
}

/// Blocked event implementation.
class SdbBlockedEventImpl implements SdbBlockedEvent {
  /// Blocked event implementation.
  SdbBlockedEventImpl({required this.name, required this.version});
  @override
  final String name;
  @override
  final int? version;

  @override
  String toString() => 'SdbBlockedEvent($name, version: $version)';
}

/// Version change implementation.
class SdbVersionChangeEventImpl implements SdbVersionChangeEvent {
  /// Version change implementation.
  SdbVersionChangeEventImpl(
    this.db,
    this.transaction,
    this.oldVersion,
    this.newVersion,
  );
  @override
  final SdbOpenDatabase db;
  @override
  final SdbOpenTransaction transaction;
  @override
  final int oldVersion;
  @override
  final int newVersion;
}
