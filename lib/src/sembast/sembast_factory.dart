part of idb_shim_sembast;

class _IdbSembastFactory extends IdbSembastFactory {
  final sdb.DatabaseFactory _databaseFactory;
  final String _path;

  String getDbPath(String dbName) =>
      _path == null ? dbName : join(_path, dbName);

  sdb.DatabaseFactory get sdbFactory => _databaseFactory;

  @override
  bool get persistent => _databaseFactory.hasStorage;

  _IdbSembastFactory(this._databaseFactory, [this._path]) : super._();

  String get name => "${idbFactoryNameSembast}";

  // get the underlying sembast database for a given database
  sdb.Database getSdbDatabase(Database db) => (db as _SdbDatabase).db;

  Future<Database> openFromSdbDatabase(sdb.Database sdbDb) =>
      _SdbDatabase.fromDatabase(this, sdbDb);

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

    _SdbDatabase db = new _SdbDatabase(this, dbName);

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
    return null;
  }
}
