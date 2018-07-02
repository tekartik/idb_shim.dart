part of idb_shim_websql;

// set to true to debug transaction life cycle
bool _debugTransaction = false;

class _WebSqlTransaction extends IdbTransactionBase {
  final IdbTransactionMeta _meta;

  bool _inactive = false;
  SqlTransaction _sqlTransaction;
  Future<SqlTransaction> _lazySqlTransaction;
  Future<SqlTransaction> get sqlTransaction {
    if (_lazySqlTransaction == null) {
      if (_debugTransaction) {
        print('transaction');
      }
      _lazySqlTransaction = idbWqlDatabase.sqlDb.transaction().then((tx) {
        _sqlTransaction = tx;

        // When inactive
        _sqlTransaction.completed.then((_) {
          if (_debugTransaction) {
            print('completed');
          }
          _inactive = true;
        });

        return tx;
      });
    }
    return _lazySqlTransaction;
  }

  _WebSqlDatabase get idbWqlDatabase => (database as _WebSqlDatabase);

  _WebSqlTransaction(Database database, this._sqlTransaction, this._meta)
      : super(database);

  @override
  _WebSqlObjectStore objectStore(String name) {
    _meta.checkObjectStore(name);
    return new _WebSqlObjectStore(
        this, idbWqlDatabase.meta.getObjectStore(name));
  }

  Future<SqlResultSet> execute(String statement, [List args]) {
    if (_inactive) {
      throw new DatabaseError("TransactionInactiveError");
    }
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

  @override
  Future<Database> get completed {
    if (_lazySqlTransaction == null) {
      return new Future.value(database);
    } else {
      return sqlTransaction.then((tx) {
        return tx.completed.then((_) {
          _inactive = true;
          return database;
        });
      });
    }
  }

  @override
  String toString() {
    return _meta.toString();
  }
}
