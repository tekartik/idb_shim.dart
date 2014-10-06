part of idb_websql;

class _IdbWebSqlError extends DatabaseError {
  int errorCode;
  
  static final int MISSING_KEY = 3;
   
  _IdbWebSqlError(this.errorCode, String message) : super(message);
   
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
