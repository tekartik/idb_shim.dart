part of idb_shim_native;

class _NativeVersionChangeEvent extends VersionChangeEvent {
  idb.VersionChangeEvent idbVersionChangeEvent;

  int get oldVersion => idbVersionChangeEvent.oldVersion;
  int get newVersion => idbVersionChangeEvent.newVersion;
  Request request;
  Object get target => request;
  Transaction get transaction => request.transaction;
  Database database;
  _NativeVersionChangeEvent(this.idbVersionChangeEvent) {
    // This is null for onChangeEvent on Database
    // but ok when opening the database
    Object currentTarget = idbVersionChangeEvent.currentTarget;
    if (currentTarget is idb.Database) {
      database = new _NativeDatabase(currentTarget);
    } else if (currentTarget is idb.Request) {
      database = new _NativeDatabase(currentTarget.result);
      _NativeTransaction transaction =
          new _NativeTransaction(database, currentTarget.transaction);
      request = new OpenDBRequest(database, transaction);
    }
  }
}

class _NativeDatabase extends Database {
  idb.Database idbDatabase;
  _NativeDatabase(this.idbDatabase) : super(idbNativeFactory);

  int get version => _catchNativeError(() => idbDatabase.version);

  @override
  ObjectStore createObjectStore(String name,
      {String keyPath, bool autoIncrement}) {
    return new _NativeObjectStore(idbDatabase.createObjectStore(name,
        keyPath: keyPath, autoIncrement: autoIncrement));
  }

  @override
  Transaction transaction(storeName_OR_storeNames, String mode) {
    return _catchNativeError(() {
      idb.Transaction idbTransaction =
          idbDatabase.transaction(storeName_OR_storeNames, mode);
      return new _NativeTransaction(this, idbTransaction);
    });
  }

  @override
  Transaction transactionList(List<String> storeNames, String mode) {
    return _catchNativeError(() {
      idb.Transaction idbTransaction =
          idbDatabase.transactionList(storeNames, mode);
      return new _NativeTransaction(this, idbTransaction);
    });
  }

  @override
  void close() {
    return _catchNativeError(() {
      idbDatabase.close();
    });
  }

  @override
  void deleteObjectStore(String name) {
    return _catchNativeError(() {
      idbDatabase.deleteObjectStore(name);
    });
  }

  @override
  Iterable<String> get objectStoreNames {
    return _catchNativeError(() {
      return idbDatabase.objectStoreNames;
    });
  }

  @override
  String get name => _catchNativeError(() => idbDatabase.name);

  @override
  Stream<VersionChangeEvent> get onVersionChange {
    StreamController<VersionChangeEvent> ctlr = new StreamController();
    idbDatabase.onVersionChange.listen(
        (idb.VersionChangeEvent idbVersionChangeEvent) {
      ctlr.add(new _NativeVersionChangeEvent(idbVersionChangeEvent));
    }, onDone: () {
      ctlr.close();
    }, onError: (error) {
      ctlr.addError(error);
    });
    return ctlr.stream;
  }
}
