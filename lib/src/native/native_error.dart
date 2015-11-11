part of idb_shim_native;

/*
class _NativeDatabaseError extends DatabaseError {
  dynamic _nativeError;
  _NativeDatabaseError(this._nativeError) : super(null) {}
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
*/

_catchNativeError(action()) {
  try {
    return action();
  } catch (e) {
    if (e is DatabaseError) {
      rethrow;
    } else {
      throw new DatabaseError(e.toString());
    }
  }
}

Future _catchAsyncNativeError(Future action()) {
  return action().catchError((e) {
    if (e is DatabaseError) {
      throw e;
    } else {
      throw new DatabaseError(e.toString());
    }
  });
}
