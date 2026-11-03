import 'package:idb_shim/idb.dart';

/// IndexedDB base database.
abstract class IdbDatabaseBase implements Database {
  /// IndexedDB database.
  IdbDatabaseBase(this._factory);
  final IdbFactory _factory;

  /// The sandbox factory that opened this database, if any.
  IdbFactory? _sandboxFactory;

  /// The name opened in [_sandboxFactory], if any.
  String? _sandboxName;

  /// The name in the implementation of a database opened through a sandbox.
  String? _implName;

  /// The factory that opened this database: the sandbox factory for a
  /// database opened through a sandbox, [implFactory] otherwise.
  @override
  IdbFactory get factory => _sandboxFactory ?? _factory;

  /// The factory of the implementation, never a sandbox.
  IdbFactory get implFactory => _factory;

  /// The name opened in the sandbox factory for a database opened through a
  /// sandbox, null otherwise. An implementation returns it as its name.
  String? get sandboxName => _sandboxName;

  /// The name of this database in the implementation: the full path of a
  /// database opened through a sandbox, [name] otherwise.
  String get implName => _implName ?? name;
}

/// Internal: [db] was opened through the sandbox [factory] with [name], it
/// reports them as its factory and name.
void idbDatabaseSetSandbox(
  IdbDatabaseBase db,
  IdbFactory factory,
  String name,
) {
  // Read before the sandbox name is set.
  db._implName ??= db.name;
  db._sandboxFactory = factory;
  db._sandboxName = name;
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
