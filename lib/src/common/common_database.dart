import 'package:idb_shim/idb.dart';

abstract class IdbDatabaseBase implements Database {
  final IdbFactory _factory;

  IdbDatabaseBase(this._factory);

  ///
  /// factory for this type of database
  ///
  @override
  IdbFactory get factory => _factory;
}

abstract class IdbVersionChangeEventBase implements VersionChangeEvent {
  @override
  Object get currentTarget => target;
}
