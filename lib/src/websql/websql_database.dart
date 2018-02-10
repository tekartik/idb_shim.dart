part of idb_shim_websql;

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

  _WebSqlVersionChangeEvent(_WebSqlDatabase database, this.oldVersion,
      this.newVersion, Transaction transaction) {
    // special transaction
    //WebSqlTransaction versionChangeTransaction = new WebSqlTransaction(database, tx, null, MODE_READ_WRITE);
    request = new OpenDBRequest(database, transaction);
  }
}

class _WebSqlDatabase extends Database with DatabaseWithMetaMixin {
  // To allow for proper schema migration if needed

  // V1 include the following schema
  // CREATE TABLE version (internal_version INT, value INT, signature TEXT)
  // INSERT INTO version (internal_version, value, signature) VALUES (1, 0, com.tekartik.idb)
  // CREATE TABLE stores (name TEXT UNIQUE, key_path TEXT, auto_increment BOOLEAN, indecies TEXT)
  static const int INTERNAL_VERSION_1 = 1;
  // CREATE TABLE stores (name TEXT UNIQUE, meta TEXT)
  static const int INTERNAL_VERSION_2 = 2;
  static const int INTERNAL_VERSION = INTERNAL_VERSION_2;

  //int version = 0;
  //bool opened = true;

  _WebSqlDatabase(String name) : super(idbWebSqlFactory) {
    meta.name = name;
  }
  _WebSqlTransaction versionChangeTransaction;
  SqlDatabase sqlDb;

  /*
  List<_WebSqlObjectStore> onVersionChangeDeletedObjectStores;
  List<_WebSqlObjectStore> onVersionChangeCreatedObjectStores;
  List<_WebSqlIndex> onVersionChangeCreatedIndexes;

  // Cache
  Map<String, _WebSqlObjectStoreMeta> stores = new Map();
  */
  final IdbDatabaseMeta meta = new IdbDatabaseMeta();

  int _getVersionFromResultSet(SqlResultSet resultSet) {
    if (resultSet.rows.length > 0) {
      return resultSet.rows[0]['value'];
    }
    return 0;
  }

  SqlDatabase _openSqlDb(String name) {
    return sqlDatabaseFactory.openDatabase(
        name, DATABASE_DB_VERSION, name, DATABASE_DB_ESTIMATED_SIZE);
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
      return tx.execute("SELECT internal_version, signature FROM version").then(
          (rs) {
        String signature = getSignatureFromResultSet(rs);
        int internalVersion = getInternalVersionFromResultSet(rs);
        // Stores table is valid since the first version
        if ((signature == INTERNAL_SIGNATURE) &&
            (internalVersion >= INTERNAL_VERSION_1)) {
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
    //var saved = initialization;
    initialization = initialization.then((_) {
      return computation();
    });
    return initialization;
  }

  Future _upgrade(SqlTransaction tx, int oldVersion, int newVersion,
      void onUpgradeNeeded(VersionChangeEvent event)) async {
    IdbVersionChangeTransactionMeta txnMeta = meta.versionChangeTransaction;

    Future createIndecies() async {
      for (String storeName in txnMeta.createdIndexes.keys) {
        _WebSqlObjectStore store =
            versionChangeTransaction.objectStore(storeName);
        List<IdbIndexMeta> indexMetas = txnMeta.createdIndexes[storeName];
        for (IdbIndexMeta indexMeta in indexMetas) {
          _WebSqlIndex index = new _WebSqlIndex(store, indexMeta);
          await index.create();
        }
      }
    }

    Future removeDeletedIndecies() async {
      for (String storeName in txnMeta.deletedIndexes.keys) {
        _WebSqlObjectStore store =
            versionChangeTransaction.objectStore(storeName);
        List<IdbIndexMeta> indexMetas = txnMeta.deletedIndexes[storeName];
        for (IdbIndexMeta indexMeta in indexMetas) {
          _WebSqlIndex index = new _WebSqlIndex(store, indexMeta);
          await index.drop();
        }
      }
    }

    Future createObjectStores() async {
      for (IdbObjectStoreMeta storeMeta in txnMeta.createdStores) {
        _WebSqlObjectStore store =
            new _WebSqlObjectStore(versionChangeTransaction, storeMeta);
        await store.create();
      }
    }

    Future updateObjectStores() async {
      for (IdbObjectStoreMeta storeMeta in txnMeta.updatedStores) {
        _WebSqlObjectStore store =
            new _WebSqlObjectStore(versionChangeTransaction, storeMeta);
        await store.update();
      }
    }

    Future removeDeletedObjectStores() async {
      for (IdbObjectStoreMeta storeMeta in txnMeta.deletedStores) {
        _WebSqlObjectStore store =
            new _WebSqlObjectStore(versionChangeTransaction, storeMeta);
        await store._deleteTable(versionChangeTransaction);
        var sqlDelete = "DELETE FROM stores WHERE name = ?";
        var sqlArgs = [store.name];
        await versionChangeTransaction.execute(sqlDelete, sqlArgs);
      }
    }

    versionChangeTransaction = new _WebSqlTransaction(this, tx, txnMeta);
    _WebSqlVersionChangeEvent event = new _WebSqlVersionChangeEvent(
        this, oldVersion, newVersion, versionChangeTransaction);

    onUpgradeNeeded(event);

    // Delete store that have been deleted
    await removeDeletedObjectStores();
    await createObjectStores();
    await createIndecies();
    await removeDeletedIndecies();

    // Update meta for updated Store
    txnMeta.updatedStores
      ..removeAll(txnMeta.createdStores)
      ..removeAll(txnMeta.deletedStores);
    await updateObjectStores();
    // nullify when done
    versionChangeTransaction = null;
  }

  Future open(
      int newVersion, void onUpgradeNeeded(VersionChangeEvent event)) async {
    Future _checkVersion(SqlTransaction tx, int oldVersion) async {
      bool upgrading = false;

      IdbTransactionMeta txnMeta = meta.transaction(null, idbModeReadWrite);
      _WebSqlTransaction transaction =
          new _WebSqlTransaction(this, tx, txnMeta);
      // Wrap in init block so that last one win

      //print("$oldVersion vs $newVersion");
      if (oldVersion != newVersion) {
        if (oldVersion > newVersion) {
          // cannot downgrade
          throw new StateError(
              "cannot downgrade from ${oldVersion} to $newVersion");
        } else {
          upgrading = true;

          Future updateVersion() async {
            // return initBlock(() {
            await transaction
                    .execute("UPDATE version SET value = ?", [newVersion]) //
                ;
            meta.version = newVersion;
          }

          //return initBlock(() {
          await _loadStores(transaction);
          if (onUpgradeNeeded != null) {
            await meta.onUpgradeNeeded(() async {
              await _upgrade(tx, oldVersion, newVersion, onUpgradeNeeded);
            });
          }
          await updateVersion();
        }
      }

      if (!upgrading) {
        meta.version = newVersion;
        await _loadStores(transaction);
      }
      return transaction.completed;
    }

    sqlDb = _openSqlDb(name);

    Future _cleanup(SqlTransaction tx) {
      return tx.execute("DROP TABLE IF EXISTS version") //
          .then((_) {
        return tx.execute(
            "CREATE TABLE version (internal_version INT, value INT, signature TEXT)");
      }).then((_) {
        return tx.execute(
            "INSERT INTO version (internal_version, value, signature)" //
            " VALUES (?, ?, ?)",
            [INTERNAL_VERSION, 0, INTERNAL_SIGNATURE]);
      }).then((_) {
        return tx.execute("DROP TABLE IF EXISTS stores");
      }).then((_) {
        return tx.execute("CREATE TABLE stores " //
            "(name TEXT UNIQUE, meta TEXT)");
        // indecies json text
      }).then((_) {
        return _checkVersion(tx, 0);
      });
    }

    Future _setup() {
      return sqlDb.transaction().then((tx) {
        return tx
            .execute(
                "SELECT internal_version, value, signature FROM version") //
            .then((SqlResultSet rs) {
          int internalVersion = getInternalVersionFromResultSet(rs);
          String signature = getSignatureFromResultSet(rs);
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

    await _setup();
  }

  @override
  ObjectStore createObjectStore(String name,
      {String keyPath, bool autoIncrement: false}) {
    IdbObjectStoreMeta storeMeta =
        new IdbObjectStoreMeta(name, keyPath, autoIncrement);
    meta.createObjectStore(storeMeta);

    _WebSqlObjectStore store =
        new _WebSqlObjectStore(versionChangeTransaction, storeMeta);
    return store;
  }

  /**
   * keyPath might not be valid before
   */
  Future _loadStores(_WebSqlTransaction transaction) {
    // this is also an indicator
    var sqlSelect = "SELECT name, meta FROM stores"; // WHERE name = ?";
    var sqlArgs = null; //[name];
    return transaction.execute(sqlSelect, sqlArgs).then((SqlResultSet rs) {
      rs.rows.forEach((Map row) {
        Map map = JSON.decode(row['meta']);
        IdbObjectStoreMeta storeMeta = new IdbObjectStoreMeta.fromMap(map);
        meta.putObjectStore(storeMeta);
      });
    });
  }

  @override
  Transaction transaction(storeName_OR_storeNames, String mode) {
    IdbTransactionMeta txnMeta =
        meta.transaction(storeName_OR_storeNames, mode);

    return new _WebSqlTransaction(this, null, txnMeta);
  }

  @override
  Transaction transactionList(List<String> stores, String mode) {
    IdbTransactionMeta txnMeta = meta.transaction(stores, mode);
    return new _WebSqlTransaction(this, null, txnMeta);
  }

  @override
  void close() {}

  // Only created when we asked for it
  // singleton
  StreamController<VersionChangeEvent> onVersionChangeCtlr;

  @override
  Stream<VersionChangeEvent> get onVersionChange {
    // only fired when a new call is made!
    if (onVersionChangeCtlr != null) {
      throw new UnsupportedError("onVersionChange should be called only once");
    }
    // sync needed in testing to make sure we receive the onCloseEvent before the
    // new database is actually open (test: websql database one keep open then one)
    onVersionChangeCtlr = new StreamController(sync: true);
    return onVersionChangeCtlr.stream;
  }
}
