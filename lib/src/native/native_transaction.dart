part of idb_shim_native;

class _NativeTransaction extends Transaction {
  idb.Transaction idbTransaction;

  _NativeTransaction(Database database, this.idbTransaction) : super(database);

  @override
  ObjectStore objectStore(String name) {
    return _catchNativeError(() {
      idb.ObjectStore idbObjectStore = idbTransaction.objectStore(name);
      return new _NativeObjectStore(idbObjectStore);
    });
  }

  @override
  Future<Database> get completed {
    return _catchAsyncNativeError(() {
      return idbTransaction.completed.then((_) {
        return database;
      });
    });
  }
}

//
// Safari fake multistore transaction
// create the transaction when objectStore is called
class _FakeMultiStoreTransaction extends Transaction {
  //List<_NativeTransaction> transactions = [];
  // We sequencialize the transactions
  _NativeTransaction lastTransaction;
  ObjectStore lastStore;
  idb.Database get idbDatabase => (database as _NativeDatabase).idbDatabase;
  String mode;
  _FakeMultiStoreTransaction(Database database, this.mode) : super(database);

  @override
  ObjectStore objectStore(String name) {
    if (lastTransaction != null) {
      // same store, reuse it
      if (lastStore.name == name) {
        return lastStore;
      }

      // will wait for the previous transaction to be completed
      // so that it wannot be re-used
      lastTransaction.completed;
    }
    lastTransaction = database.transaction(name, mode);
    lastStore = lastTransaction.objectStore(name);
    return lastStore;
  }

  @override
  Future<Database> get completed {
    if (lastTransaction == null) {
      return new Future.value(database);
    } else {
      // Somehow waiting for all transaction hangs
      // just wait for the last one created!
      return lastTransaction.completed;
    }
  }
}
