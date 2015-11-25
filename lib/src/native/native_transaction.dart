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
  List<_NativeTransaction> transactions = [];
  idb.Database get idbDatabase => (database as _NativeDatabase).idbDatabase;
  String mode;
  _FakeMultiStoreTransaction(Database database, this.mode) : super(database);

  @override
  ObjectStore objectStore(String name) {
      _NativeTransaction transaction = database.transaction(name, mode);
      // add the transaction to our list
      transactions.add(transaction);

     return transaction.objectStore(name);
  }

  @override
  Future<Database> get completed {
    if (transactions.isEmpty) {
      return new Future.value(database);
    } else {
      // Somehow waiting for all transaction hangs
      // just wait for the last one created!
      return transactions.last.completed;
    }
  }
}