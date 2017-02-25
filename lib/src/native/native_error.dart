part of idb_shim_native;

//bool dev = true;

_catchNativeError(action()) {
  try {
    return action();
  } on Error catch (e) {
    if (e is DatabaseError) {
      rethrow;
    } else {
      throw new DatabaseError(e.toString());
    }
  } catch (e) {
    if (e is DatabaseError) {
      rethrow;
    } else {
      //devPrint(e);
      //devPrint(e.runtimeType);
      throw new DatabaseError(e.toString());
    }
  }
}

//
// We no longer catch the native exception asynchronously
// as it makes the stack trace lost...
//
Future _catchAsyncNativeError(Future action()) {
  Future result = _catchNativeError(action);
  return result;
}
