import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sembast/sembast_database.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart' as sdb;

class IdbFactorySembastImpl extends IdbFactoryBase
    implements IdbFactorySembast {
  final sdb.DatabaseFactory _databaseFactory;
  final String _path;

  String getDbPath(String dbName) =>
      _path == null ? dbName : join(_path, dbName);

  sdb.DatabaseFactory get sdbFactory => _databaseFactory;

  @override
  bool get persistent => _databaseFactory.hasStorage;

  IdbFactorySembastImpl(this._databaseFactory, [this._path]);

  String get name => "${idbFactoryNameSembast}";

  // get the underlying sembast database for a given database
  sdb.Database getSdbDatabase(Database db) => (db as DatabaseSembast).db;

  Future<Database> openFromSdbDatabase(sdb.Database sdbDb) =>
      DatabaseSembast.fromDatabase(this, sdbDb);

  @override
  Future<Database> open(String dbName,
      {int version,
      OnUpgradeNeededFunction onUpgradeNeeded,
      OnBlockedFunction onBlocked}) {
    // check params
    if ((version == null) != (onUpgradeNeeded == null)) {
      return new Future.error(new ArgumentError(
          'version and onUpgradeNeeded must be specified together'));
    }
    if (version == 0) {
      return new Future.error(new ArgumentError('version cannot be 0'));
    } else if (version == null) {
      version = 1;
    }

    // name null ok for in memory
    // if (dbName == null) {
    //  return new Future.error(new ArgumentError('name cannot be null'));
    // }

    DatabaseSembast db = new DatabaseSembast(this, dbName);

    return db.open(version, onUpgradeNeeded).then((_) {
      return db;
    });
  }

  @override
  Future<IdbFactory> deleteDatabase(String dbName,
      {OnBlockedFunction onBlocked}) async {
    if (dbName == null) {
      return new Future.error(new ArgumentError('dbName cannot be null'));
    }
    await _databaseFactory.deleteDatabase(getDbPath(dbName));
    return this;
  }

  @override
  bool get supportsDatabaseNames {
    return false;
  }

  Future<List<String>> getDatabaseNames() {
    throw 'getDatabaseNames not supported';
  }

  // common implementation
  int cmp(Object first, Object second) => compareKeys(first, second);
}
