import 'package:idb_shim/idb.dart';

/// IndexedDB base database.
abstract class IdbDatabaseBase implements Database {
  final IdbFactory _factory;

  /// IndexedDB database.
  IdbDatabaseBase(this._factory);

  ///
  /// factory for this type of database
  ///
  @override
  IdbFactory get factory => _factory;
}

/// IndexedDB base version change event.
abstract class IdbVersionChangeEventBase implements VersionChangeEvent {
  @override
  Object get currentTarget => target;
}
