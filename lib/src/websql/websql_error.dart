part of idb_shim_websql;

class _IdbWebSqlError extends DatabaseError {
  int errorCode;

  static final int MISSING_KEY = 3;

  _IdbWebSqlError(this.errorCode, String message) : super(message);

  @override
  String toString() {
    String text = "IdbWebSqlError(${errorCode})";
    if (message != null) {
      text += ": $message";
    }
    return text;
  }
}

class _WebSqlDatabaseError extends DatabaseError {
  dynamic _nativeError;

  int get code {
    if (_nativeError is SqlError) {
      return (_nativeError as SqlError).code;
    }
    return 0;
  }

  _WebSqlDatabaseError(this._nativeError) : super(null);

  @override
  String get message {
    if (_nativeError is SqlError) {
      return (_nativeError as SqlError).message;
    }
    return _nativeError.toString();
  }
}
