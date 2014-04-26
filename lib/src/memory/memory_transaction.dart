part of idb_memory;

abstract class WithCurrentTransaction {
  Transaction currentTransaction;
}

class _MemoryTransaction extends Transaction {
  List<String> _stores;

  _MemoryTransaction(Database database): super(database) {
    // Auto complete for empty transaction
    _asyncCompleteIfDone();
  }

  _MemoryDatabase get memoryDatabase => database as _MemoryDatabase;

  @override
  ObjectStore objectStore(String name) {
    return new MemoryObjectStore(this, memoryDatabase.stores[name]);
  }

  //  @override
  //  void beginOperation() {
  //    print("beginOperation $hashCode $this");
  //    super.beginOperation();
  //  }
  //
  //  @override
  //  void endOperation() {
  //    print("endOperation $hashCode $this");
  //    super.endOperation();
  //  }

  //  @override
  //  Future addOperation(Future computation) {
  //    return active.then((_) {
  //      return super.addOperation(computation);
  //    });
  //  }
  /*
     * Wait for the transaction to be the current one
     */
  Future get _active {
    //print("active $hashCode $this");
    WithCurrentTransaction database = memoryDatabase;
    Transaction currentTransaction = database.currentTransaction;

    // trigger
    _beginOperation();
    if (currentTransaction == null) {
      database.currentTransaction = this;
      // print("added cause null $this");
      _endOperation();
      return new Future.value();
    } else if (currentTransaction == this) {
      // print("already added $this");
      _endOperation();
      return new Future.value();
    } else {
      // wait our turn
      return currentTransaction.completed.then((_) {
        //        Transaction newCurrentTransaction = database.currentTransaction;
        //        if (newCurrentTransaction == currentTransaction) {
        //          database.currentTransaction = null;
        //        }


        // sync important so that we don't loose our turn
        return new Future(() => _active).then((_) {
          // complete asynchronously
          // so that we can breath between 2 requests
          
        }).whenComplete(() {
          _endOperation();
        });
        //return active;
      });
    }
  }


  void complete() {
    // print("complete $hashCode $this");
    // It can be null for empty transaction
    if ((memoryDatabase.currentTransaction != this) && (memoryDatabase.currentTransaction != null)) {
      print("error $hashCode $this");
      throw new StateError("internal error - complete - not the current transaction");
    }

    // Mark current transaction as null
    WithCurrentTransaction database = (this.database as WithCurrentTransaction);
    database.currentTransaction = null;

    completer.complete(database);
    // Disable transaction for good
    _operationCount = null;
  }


  Completer<Database> completer = new Completer();
  int _operationCount = 0;

  /**
    * must be used in pair
    */
  void _beginOperation() {
    //print("begin $_operationCount");
    _operationCount++;
  }

  void _endOperation() {
    //print("end $_operationCount");
    --_operationCount;
    // Make it breath
    _asyncCompleteIfDone();
  }

  /**
      * Add an operation in the current transaction
      * so that it gets completed in the next event loop
      */
  Future _enqueue(computation()) {
    if (memoryDatabase.currentTransaction != this) {
      throw new StateError("internal error - addOperation - not the current transaction");
    }

    _beginOperation();
    if (computation == null) {
      _endOperation();
      return new Future.value();
    }

    var result;
    try {
      result = computation();
    } catch (e) {
      _endOperation();
      return new Future.error(e);
    }
    
    _endOperation();
    return new Future.value(result);
  }

  /**
    * Add an operation in the current transaction
    * so that it gets completed in the next event loop
    */
  Future _enqueueFuture([Future computation]) {
    if (memoryDatabase.currentTransaction != this) {
      throw new StateError("internal error - addOperation - not the current transaction");
    }

    _beginOperation();
    if (computation == null) {
      _endOperation();
      return new Future.value();
    }

    return computation.then((result) {

      return result;
    }, onError: (e, st) {
      //      print(e);
      //      print(st);
      //      return new Future.error(e);
      throw e;
    }).whenComplete(() {
      _endOperation();
    });
  }

  void _asyncCompleteIfDone() {
    if (_operationCount == 0) {
      new Future(_completeIfDone);
    }
  }


  void _completeIfDone() {
    if (_operationCount == 0) {
      complete();
    }
  }

  @override
  Future<Database> get completed => completer.future;

  @override
  String toString() {
    return "$hashCode operation count " + _operationCount.toString();
  }

}
