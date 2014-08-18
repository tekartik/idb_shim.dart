part of idb_websql;

class _WebSqlVersionChangeEvent extends VersionChangeEvent {

  int oldVersion;
  int newVersion;
  Request request;
  Object get target => request;
  Database get database => transaction.database;
  /**
     * added for convenience
     */
  Transaction get transaction => request.transaction;

  _WebSqlVersionChangeEvent(_WebSqlDatabase database, this.oldVersion, this.newVersion, Transaction transaction) {

    // special transaction
    //WebSqlTransaction versionChangeTransaction = new WebSqlTransaction(database, tx, null, MODE_READ_WRITE);
    request = new OpenDBRequest(database, transaction);
  }
}

class _WebSqlDatabase extends Database {

  // To allow for proper schema migration if needed

  // V1 include the following schema
  // CREATE TABLE version (internal_version INT, value INT, signature TEXT)
  // INSERT INTO version (internal_version, value, signature) VALUES (1, 0, com.tekartik.idb)
  // CREATE TABLE stores (name TEXT UNIQUE, key_path TEXT, auto_increment BOOLEAN, indecies TEXT)
  static const int INTERNAL_VERSION_1 = 1;
  static const int INTERNAL_VERSION = INTERNAL_VERSION_1;

  //int version = 0;
  //bool opened = true;
  IdbWebSqlFactory factory;
  String name;
  _WebSqlDatabase(this.factory, this.name);
  _WebSqlTransaction versionChangeTransaction;
  SqlDatabase sqlDb;

  List<_WebSqlObjectStore> onVersionChangeCreatedObjectStores;
  List<_WebSqlIndex> onVersionChangeCreatedIndexes;

  // Cache
  Map<String, _WebSqlObjectStore> stores = new Map();

  int version;

  int _getVersionFromResultSet(SqlResultSet resultSet) {
    if (resultSet.rows.length > 0) {
      return resultSet.rows[0]['value'];
    }
    return 0;
  }

  SqlDatabase _openSqlDb(String name) {
    return sqlDatabaseFactory.openDatabase(name, DATABASE_DB_VERSION, name, DATABASE_DB_ESTIMATED_SIZE);
  }

  Future _delete() {

    List<String> tableNamesFromResultSet(SqlResultSet rs) {
      List<String> names = [];
      rs.rows.forEach((row) {
        names.add(_WebSqlObjectStore.getSqlTableName(row['name']));
      });
      return names;
    }

    Future deleteStores(SqlTransaction tx) {
      // delete all stores
      // this exists since v1
      var sqlSelect = "SELECT name FROM stores";
      return tx.execute(sqlSelect).then((SqlResultSet rs) {
        List<String> names = tableNamesFromResultSet(rs);
        return tx.dropTablesIfExists(names);
      });
    }
    // delete all tables
    SqlDatabase sqlDb = _openSqlDb(name);
    return sqlDb.transaction().then((tx) {
      return tx.execute("SELECT internal_version, signature FROM version").then((rs) {
        String signature = _getSignatureFromResultSet(rs);
        int internalVersion = _getInternalVersionFromResultSet(rs);
        // Stores table is valid since the first version
        if ((signature == INTERNAL_SIGNATURE) && (internalVersion >= INTERNAL_VERSION_1)) {
          // delete all the object store table
          return deleteStores(tx).then((_) {
            // then the system tables
            return tx.dropTableIfExists("version").then((_) {
              return tx.dropTableIfExists("stores");
            });
          });
        }
      }, onError: (e) {
        // No such version table
        // assume everything is fine
        // don't create anyting
      });
    });

  }

  // This is set on object store create and index create
  Future initialization = new Future.value();

  // very ugly
  // basically some init function are not async, this is a hack to group action here...
  Future initBlock(Future computation()) {
    var saved = initialization;
    initialization = initialization.then((_) {
      return computation();
    });
    return initialization;

  }

  Future open(int newVersion, void onUpgradeNeeded(VersionChangeEvent event)) {

    Future _checkVersion(SqlTransaction tx, int oldVersion) {
      bool upgrading = false;
      _WebSqlTransaction transaction = new _WebSqlTransaction(this, tx, null, IDB_MODE_READ_WRITE);
      //print("$oldVersion vs $newVersion");
      if (oldVersion != newVersion) {
        if (oldVersion > newVersion) {
          // cannot downgrade
          return new Future.error(new StateError("cannot downgrade from ${oldVersion} to $newVersion"));
        } else {
          upgrading = true;

          Future stepUpdateVersion() {
            // Wrap in init block so that last one win
            // return initBlock(() {
            return transaction.execute("UPDATE version SET value = ?", [newVersion]) //
            .then((_) {
              this.version = newVersion;
            })//})
            .then((_) {
              // Only mark as open when the first transaction complete
              return transaction.completed;
            });
          }

          Future stepCreateIndexes() {
            int index = 0;
            _createNextIndex() {
              if (index >= onVersionChangeCreatedIndexes.length) {
                return stepUpdateVersion();
              }
              return onVersionChangeCreatedIndexes[index++].create().then((_) {
                return _createNextIndex();
              });
            }
            return _createNextIndex();
          }

          Future stepCreateObjectStores() {
            int index = 0;
            createNextObjectStore() {
              if (index >= onVersionChangeCreatedObjectStores.length) {
                return stepCreateIndexes();
              }
              return onVersionChangeCreatedObjectStores[index++].create().then((_) {
                return createNextObjectStore();
              });
            }
            return createNextObjectStore();
          }

          Future createNewObjects() {
            return stepCreateObjectStores();
          }

          //return initBlock(() {
          return _loadStores(transaction)//})
          .then((_) {
            if (onUpgradeNeeded != null) {
              _WebSqlTransaction transaction = new _WebSqlTransaction(this, tx, null, IDB_MODE_READ_WRITE);
              _WebSqlVersionChangeEvent event = new _WebSqlVersionChangeEvent(this, oldVersion, newVersion, transaction);
              versionChangeTransaction = event.transaction;

              onVersionChangeCreatedObjectStores = [];
              onVersionChangeCreatedIndexes = [];

              onUpgradeNeeded(event);
              // nulliy when done
              versionChangeTransaction = null;

              return createNewObjects();
            } else {
              return stepUpdateVersion();
            }

          });


        }
      }
      if (!upgrading) {
        this.version = newVersion;
        return _loadStores(transaction);
      }
      return transaction.completed;
    }

    sqlDb = _openSqlDb(name);

    Future _cleanup(SqlTransaction tx) {
      return tx.execute("DROP TABLE IF EXISTS version") //
      .then((_) {
        return tx.execute("CREATE TABLE version (internal_version INT, value INT, signature TEXT)");
      }).then((_) {
        return tx.execute("INSERT INTO version (internal_version, value, signature)" //
        " VALUES (?, ?, ?)", [INTERNAL_VERSION, 0, INTERNAL_SIGNATURE]);
      }).then((_) {
        return tx.execute("DROP TABLE IF EXISTS stores");
      }).then((_) {
        return tx.execute("CREATE TABLE stores " //
        "(name TEXT UNIQUE, key_path TEXT, auto_increment BOOLEAN, indecies TEXT)");
        // indecies json text
      }).then((_) {
        return _checkVersion(tx, 0);
      });
    }

    Future _setup() {
      return sqlDb.transaction().then((tx) {
        return tx.execute("SELECT internal_version, value, signature FROM version") //
        .then((SqlResultSet rs) {
          int internalVersion = _getInternalVersionFromResultSet(rs);
          String signature = _getSignatureFromResultSet(rs);
          if (signature != INTERNAL_SIGNATURE) {
            return _cleanup(tx);
          }
          if (internalVersion != INTERNAL_VERSION) {
            return _cleanup(tx);
          } else {
            int oldVersion = _getVersionFromResultSet(rs);
            return _checkVersion(tx, oldVersion);
          }
        }, onError: (e) {
          return _cleanup(tx);
        });
      });
    }

    return _setup();

  }



  @override
  ObjectStore createObjectStore(String name, {String keyPath, bool autoIncrement}) {
    if (versionChangeTransaction == null) {
      throw new StateError("cannot create objectStore outside of a versionChangedEvent");
    }
    _WebSqlObjectStore store = new _WebSqlObjectStore(name, versionChangeTransaction, keyPath, autoIncrement);

    // Put in the map
    stores[name] = store;

    // Add for later creation
    onVersionChangeCreatedObjectStores.add(store);

    //    MemoryObjectStoreData data =  new MemoryObjectStoreData(name, keyPath, autoIncrement);
    //    stores[name] = data;
    //    return new MemoryObjectStore(null, data);

    // This is a future
    // Special as create is call in a synchronized method
    //    initBlock(() {
    //      return store.create(keyPath, autoIncrement);
    //    });

    return store;
  }

  _initStoreFromRow(_WebSqlTransaction transaction, Map row) {
    String name = row['name'];
    String keyPath = row['key_path'];
    bool autoIncrement = row['auto_increment'] > 0;

    _WebSqlObjectStore store = new _WebSqlObjectStore(name, transaction, null, null);
    store._initOptions(keyPath, autoIncrement);

    String indeciesText = row['indecies'];

    // merge lazy loaded data
    Map indeciesData = _WebSqlIndex.indeciesDataFromString(indeciesText);
    indeciesData.forEach((name, data) {
      _WebSqlIndex index = new _WebSqlIndex(store, name, data);
      store.indecies[name] = index;

      // save store in cache



      //             if (keyPath == null && !autoIncrement) {
      //               throw new ArgumentError("neither keyPath nor autoIncrement set");
      //             }
    });
    stores[name] = store;
  }
  /**
   * keyPath might not be valid before
   */
  Future _loadStores(_WebSqlTransaction transaction) {
    // this is also an indicator
    var sqlSelect = "SELECT name, key_path, auto_increment, indecies FROM stores"; // WHERE name = ?";
    var sqlArgs = null; //[name];
    return transaction.execute(sqlSelect, sqlArgs).then((SqlResultSet rs) {
      rs.rows.forEach((Map row) {
        _initStoreFromRow(transaction, row);
      });
    });

  }

  bool _containsStore(String storeName) {
    return stores.keys.contains(storeName);
  }

  @override
  Transaction transaction(storeName_OR_storeNames, String mode) {
    List<String> storeNames;
    if (storeName_OR_storeNames is List) {
      storeNames = storeName_OR_storeNames;

      // check stores exist
      for (String storeName in storeNames) {
        if (!_containsStore(storeName)) {
          throw new DatabaseStoreNotFoundError();
        }
      }
    } else {
      String storeName = storeName_OR_storeNames;
      storeNames = [storeName];

      // check store exist
      if (!_containsStore(storeName)) {
        throw new DatabaseStoreNotFoundError();
      }
    }
    return new _WebSqlTransaction(this, null, storeNames, mode);
  }

  @override
  Transaction transactionList(List<String> stores, String mode) {
    return new _WebSqlTransaction(this, null, stores, mode);
  }

  _WebSqlTransaction newRawTransaction(String mode) {
    return new _WebSqlTransaction(this, null, null, mode);
  }

  //  @override
  //  Transaction transactionList(List<String> storeNames, String mode) {
  //    return newRawTransaction;
  //  }

  @override
  void close() {
    //opened = false;
    // nothing?
    //factory.dbMap[name];
    //stores = null; // so that it crashes
  }

  @override
  void deleteObjectStore(String name) {
    if (versionChangeTransaction == null) {
      throw new StateError("cannot call deleteObjectStore outside of a versionChangedEvent");
    }

    _WebSqlObjectStore store = stores[name];

    if (store != null) {
      // delete the table
      stores[name] = null;

      initBlock(() {
        return store._deleteTable(versionChangeTransaction).then((_) {
          var sqlDelete = "DELETE FROM stores WHERE name = ?";
          var sqlArgs = [name];
          return versionChangeTransaction.execute(sqlDelete, sqlArgs);
        });
      });
    }
  }

  Iterable<String> get objectStoreNames => stores.keys;

  // Only created when we asked for it
  // singleton
  StreamController<VersionChangeEvent> onVersionChangeCtlr;

  @override
  Stream<VersionChangeEvent> get onVersionChange {
    /**
  * only fired when a new call is made!
  */
    if (onVersionChangeCtlr != null) {
      throw new UnsupportedError("onVersionChange should be called only once");
    }
    // sync needed in testing to make sure we receive the onCloseEvent before the
    // new database is actually open (test: websql database one keep open then one)
    onVersionChangeCtlr = new StreamController(sync: true);
    return onVersionChangeCtlr.stream;
  }
  /*
  @override
  String toString() {
    return 'db: $name';
  }
  */
}
