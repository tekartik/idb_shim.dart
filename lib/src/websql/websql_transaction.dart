part of idb_shim_websql;

class _WebSqlTransaction extends Transaction { // extends CommonTransaction {

  //int _operationCount = 0;

  // readonly or readwrite
  String _mode;

  List<String> storeNames;

  SqlTransaction _sqlTransaction;
  Future<SqlTransaction> _lazySqlTransaction;
  Future<SqlTransaction> get sqlTransaction {
    if (_lazySqlTransaction == null) {
      _lazySqlTransaction = idbWqlDatabase.sqlDb.transaction().then((tx) {
        _sqlTransaction = tx;
        return tx;
      });
    }
    return _lazySqlTransaction;
  }

  _WebSqlDatabase get idbWqlDatabase => (database as _WebSqlDatabase);
  
  _WebSqlTransaction(Database database, this._sqlTransaction, this.storeNames, this._mode): super(database);

  @override
  ObjectStore objectStore(String name) {
    
    _WebSqlObjectStore store = idbWqlDatabase._getStore(this, name);
    return store;
  }

  Future<SqlResultSet> execute(String statement, [List args]) {
    if (args == null) {
      args = [];
    }
    if (_sqlTransaction != null) {
      return _sqlTransaction.execute(statement, args).catchError((e) {
        // convert to error that we understand
        throw new _WebSqlDatabaseError(e);
      });
    } else {
      return sqlTransaction.then((tx) {
        return tx.execute(statement, args).catchError((e) {
          // convert to error that we understand
          throw new _WebSqlDatabaseError(e);
        });
      });
    }
  }

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
  
  toString() {
    return _mode;
  }
}
