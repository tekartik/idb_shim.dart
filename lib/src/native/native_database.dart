part of idb_shim_native;

class _NativeVersionChangeEvent extends IdbVersionChangeEventBase {
  idb.VersionChangeEvent idbVersionChangeEvent;

  @override
  int get oldVersion => idbVersionChangeEvent.oldVersion;

  @override
  int get newVersion => idbVersionChangeEvent.newVersion;
  Request request;
  @override
  Object get target => request;
  @override
  Transaction get transaction => request.transaction;

  @override
  Database database;
  _NativeVersionChangeEvent(this.idbVersionChangeEvent) {
    // This is null for onChangeEvent on Database
    // but ok when opening the database
    dynamic currentTarget = idbVersionChangeEvent.currentTarget;
    if (currentTarget is idb.Database) {
      database = DatabaseNative(currentTarget);
    } else if (currentTarget is idb.Request) {
      database = DatabaseNative(currentTarget.result as idb.Database);
      TransactionNative transaction =
          TransactionNative(database, currentTarget.transaction);
      request = OpenDBRequest(database, transaction);
    }
  }
}

class DatabaseNative extends IdbDatabaseBase {
  idb.Database idbDatabase;
  DatabaseNative(this.idbDatabase) : super(idbNativeFactory);

  @override
  int get version => _catchNativeError(() => idbDatabase.version);

  @override
  ObjectStore createObjectStore(String name,
      {String keyPath, bool autoIncrement}) {
    return _catchNativeError(() {
      return _NativeObjectStore(idbDatabase.createObjectStore(name,
          keyPath: keyPath, autoIncrement: autoIncrement));
    });
  }

  @override
  TransactionNativeBase transaction(storeName_OR_storeNames, String mode) {
    // bug in 1.13
    // It only happens in dart for list
    // https://github.com/dart-lang/sdk/issues/25013

    // Safari has the issue of not supporting multistore
    // simulate them!
    try {
      return _catchNativeError(() {
        idb.Transaction idbTransaction =
            idbDatabase.transaction(storeName_OR_storeNames, mode);
        return TransactionNative(this, idbTransaction);
      });
    } catch (e) {
      // Only handle the issue for non empty list returning a NotFoundError
      if ((storeName_OR_storeNames is List) &&
          (storeName_OR_storeNames.isNotEmpty) &&
          (_isNotFoundError(e))) {
        List<String> stores = storeName_OR_storeNames;

        // Make sure they indeed exists
        bool allFound = true;
        for (String store in stores) {
          if (!objectStoreNames.contains(store)) {
            allFound = false;
            break;
          }
        }

        if (allFound) {
          if (!isDartVm) {
            // In javascript this is likely a safari issue...
            return FakeMultiStoreTransactionNative(this, mode);
          } else {
            // This is likely the 1.13 bug
            try {
              return _catchNativeError(() {
                idb.Transaction idbTransaction = idbDatabase.transaction(
                    html_common.convertDartToNative_SerializedScriptValue(
                        storeName_OR_storeNames),
                    mode);
                return TransactionNative(this, idbTransaction);
              });
            } catch (e2) {}
          }
        }
      }
      rethrow;
    }
  }

  bool _isNotFoundError(e) {
    if (e is DatabaseError) {
      String message = e.toString().toLowerCase();
      if (message.contains('notfounderror')) {
        return true;
      }
    }
    return false;
  }

  @override
  Transaction transactionList(List<String> storeNames, String mode) =>
      transaction(storeNames, mode);

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
    StreamController<VersionChangeEvent> ctlr = StreamController();
    idbDatabase.onVersionChange.listen(
        (idb.VersionChangeEvent idbVersionChangeEvent) {
      ctlr.add(_NativeVersionChangeEvent(idbVersionChangeEvent));
    }, onDone: () {
      ctlr.close();
    }, onError: (error) {
      ctlr.addError(error);
    });
    return ctlr.stream;
  }
}
