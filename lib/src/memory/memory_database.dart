part of idb_memory;

class _MemoryVersionChangeEvent extends VersionChangeEvent {

  int oldVersion;
  int newVersion;
  Request request;
  Object get target => request;
  Database get database => transaction.database;
  /**
     * added for convenience
     */
  Transaction get transaction => request.transaction;

  _MemoryVersionChangeEvent(_MemoryDatabase database, this.oldVersion, this.newVersion) {

    // special transaction
    _MemoryTransaction versionChangeTransaction = new _MemoryTransaction(database, IDB_MODE_READ_WRITE);
    request = new OpenDBRequest(database, versionChangeTransaction);
  }
}

class _MemoryDatabaseData {
  int version = 0;

  Map<String, _MemoryObjectStoreData> stores = new Map();
}
class _MemoryDatabase extends Database with WithCurrentTransaction {

  int _version;

  int get version => _version;
  set version(int newVersion) {
    _version = newVersion;
    _data.version = newVersion;
  }

  int get dataVersion => _data.version;

  bool opened = true;
  IdbMemoryFactory factory;
  String name;
  _MemoryDatabase(this.factory, this.name, this._data) {
    if (_data == null) {
      _data = new _MemoryDatabaseData();
    }
  }
  _MemoryDatabaseData _data;

  Map<String, _MemoryObjectStoreData> get stores => _data.stores;

  // Set when the database is upgraded elsewhere
  _MemoryError _error;

  _MemoryTransaction versionChangeTransaction;

  Future open(int newVersion, void onUpgradeNeeded(VersionChangeEvent event)) {
    Completer completer = new Completer();

    void _checkVersion() {
      bool upgrading = false;
      if (onUpgradeNeeded != null) {
        if (dataVersion < newVersion) {
          upgrading = true;
          _MemoryVersionChangeEvent event = new _MemoryVersionChangeEvent(this, dataVersion, newVersion);
          versionChangeTransaction = event.transaction;
          versionChangeTransaction._active(() {
            return versionChangeTransaction._enqueue(() {
              onUpgradeNeeded(event);
              // nulliyfy when done
              versionChangeTransaction = null;

            });
          }).then((_) {
            event.transaction.completed.then((_) {
              version = newVersion;
              completer.complete();
            });
          });
        } else if (dataVersion > newVersion) {
          // cannot downgrade
          completer.completeError(new StateError("cannot downgrade from ${this.version} to $newVersion"));
          upgrading = true;
        }
      }
      if (!upgrading) {
        version = newVersion;
        completer.complete();
      }
    }

    if (newVersion == null) {
      newVersion = 1;
    }
    _checkVersion();


    return completer.future;

  }

  @override
  ObjectStore createObjectStore(String name, {String keyPath, bool autoIncrement}) {
    _MemoryObjectStoreData data = new _MemoryObjectStoreData(name, keyPath, autoIncrement);
    stores[name] = data;
    return new MemoryObjectStore(versionChangeTransaction, data);
  }

  bool _containsStore(String storeName) {
    return stores.keys.contains(storeName);
  }
  
  @override
  Transaction transaction(storeName_OR_storeNames, String mode) {
    // Check store(s) exist
    if (storeName_OR_storeNames is String) {
      if (!_containsStore(storeName_OR_storeNames)) {
        throw new DatabaseStoreNotFoundError();
      }
    } else {
      for (String storeName in storeName_OR_storeNames) {
        if (!_containsStore(storeName)) {
          throw new DatabaseStoreNotFoundError();
        }
      }
    }
    return new _MemoryTransaction(this, mode);
  }

  @override
  Transaction transactionList(List<String> storeNames, String mode) {
    _MemoryTransaction transaction = new _MemoryTransaction(this, mode);
    return transaction;
  }

  @override
  void close() {
    opened = false;
    // nothing?
    //factory.dbMap[name];
    //stores = null; // so that it crashes
  }

  @override
  void deleteObjectStore(String name) {
    stores[name] = null;
  }

  Iterable<String> get objectStoreNames => stores.keys;

  @override
  String toString() {
    return 'db: $name';
  }

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
    onVersionChangeCtlr = new StreamController();
    return onVersionChangeCtlr.stream;
  }

}
