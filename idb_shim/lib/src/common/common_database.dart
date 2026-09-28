import 'package:idb_shim/idb.dart';

/// IndexedDB base database.
abstract class IdbDatabaseBase implements Database {
  /// IndexedDB database.
  IdbDatabaseBase(this._factory);
  final IdbFactory _factory;

  /// factory for this type of database
  @override
  IdbFactory get factory => _factory;
}

/// IndexedDB base version change event.
abstract class IdbVersionChangeEventBase implements VersionChangeEvent {
  @override
  Object get currentTarget => target;

  /// The new version, `null` when the database is being deleted (an event of
  /// [Database.onVersionChange] only, never in `onUpgradeNeeded`).
  int? get newVersionOrNull => newVersion;
}

/// Version change event helpers.
extension VersionChangeEventExtension on VersionChangeEvent {
  /// The new version, `null` when the database is being deleted (an event of
  /// [Database.onVersionChange] only, never in `onUpgradeNeeded`, where
  /// [VersionChangeEvent.newVersion] is always set).
  int? get newVersionOrNull {
    var self = this;
    if (self is IdbVersionChangeEventBase) {
      return self.newVersionOrNull;
    }
    return newVersion;
  }
}
