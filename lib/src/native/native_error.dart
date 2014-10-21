part of idb_shim_native;

class _NativeDatabaseError extends DatabaseError {
  dynamic _nativeError;
  _NativeDatabaseError(this._nativeError) : super(null) {

  }
  String get message {
    if (_nativeError is html.Event) {
      if (_nativeError.currentTarget is idb.Request) {
        if (_nativeError.currentTarget.error is html.DomError) {
          return _nativeError.currentTarget.error.message;

        }
      }
    }
    return _nativeError.toString();
  }
}
