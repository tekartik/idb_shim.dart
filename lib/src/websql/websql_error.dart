part of idb_websql;

class _WebSqlDatabaseError extends DatabaseError {
  dynamic _nativeError;
  
  int get code {
    if (_nativeError is SqlError) {
      return _nativeError.code;
    }
    return 0;
  }
  
  _WebSqlDatabaseError(this._nativeError) : super(null);
  
  String get message {
    if (_nativeError is SqlError) {
      return _nativeError.message;
    }
    return _nativeError.toString();
  }
}
