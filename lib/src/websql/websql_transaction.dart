part of idb_websql;

class _WebSqlTransaction extends Transaction { // extends CommonTransaction {

  int _operationCount = 0;

  //  /**
  //     * must be used in pair
  //     */
  //  void _beginOperation() {
  //    _operationCount++;
  //  }
  //
  //  void _endOperation() {
  //    --_operationCount;
  //    // Make it breath
  //    _asyncCompleteIfDone();
  //  }
  //
  //  Completer<Database> _completer = new Completer();

  // readonly or readwrite
  String _mode;

  List<String> storeNames;

  SqlTransaction _sqlTransaction;
  Future<SqlTransaction> _lazySqlTransaction;
  Future<SqlTransaction> get sqlTransaction {
    if (_lazySqlTransaction == null) {
      _WebSqlDatabase database = (this.database) as _WebSqlDatabase;
      _lazySqlTransaction = database.sqlDb.transaction().then((tx) {
        _sqlTransaction = tx;
        return tx;
      });
    }
    return _lazySqlTransaction;
  }

  /**
   * Add additonal initialization
   */
  //  @override
  //  Future get active {
  //    return super.active.then((result) {
  //      return sqlTransaction.then((_) {
  //        return result;
  //      });
  //
  //    });
  //  }

  _WebSqlTransaction(Database database, this._sqlTransaction, this.storeNames, this._mode): super(database);

  @override
  ObjectStore objectStore(String name) {
    _WebSqlObjectStore store = new _WebSqlObjectStore(name, this, null, null);
    return store;
  }

  Future<SqlResultSet> execute(String statement, [List args]) {
    if (args == null) {
      args = [];
    }
    if (_sqlTransaction != null) {
      return _sqlTransaction.execute(statement, args);
    } else {
      return sqlTransaction.then((tx) {
        return tx.execute(statement, args);
      });
    }
    //    return addOperation(sqlTransaction.then((tx) {
    //      return tx.execute(statement, args);
    //    }));

  }



  //  void complete() {
  //    if (_sqlTransaction != null) {
  //      _sqlTransaction.commit();
  //    }
  //    if (!_completer.isCompleted) {
  //      _completer.complete(database);
  //    }



  //  @override
  //  Future<Database> get completed {
  //    return idbTransaction.completed.then((_) {
  //      return database;
  //    });
  //  }



  //  @override
  //  Future<Database> get completed {
  //    // This take care of empty transaction
  //    _asyncCompleteIfDone();
  //
  //    return _completer.future;
  //  }

  Future<Database> get OLDcompleted {
    if (_sqlTransaction == null) {
      return sqlTransaction.then((tx) {
        return tx.completed.then((_) {
          return database;
        });
      });
    } else {
      return _sqlTransaction.completed.then((_) {
        return database;
      });
    }
  }
  
  Future<Database> get completed {
      if (_lazySqlTransaction == null) {
        return new Future.value(database);
      } else {
        return sqlTransaction.then((tx) {
          return tx.completed.then((_) {
            return database;  
          });
        });
      }
    }
  
  //
  //  void _completeIfDone() {
  //    if (_operationCount == 0) {
  //
  //      complete();
  //    }
  //  }
  //
  //  void _asyncCompleteIfDone() {
  //    new Future(_completeIfDone);
  //  }
}
