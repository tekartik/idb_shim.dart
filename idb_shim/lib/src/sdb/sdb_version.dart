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
