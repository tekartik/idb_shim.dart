import 'dart:async';

import 'package:idb_shim/idb.dart';

//bool dev = true;

T catchNativeError<T>(T action()) {
  try {
    return action();
  } on Error catch (e) {
    if (e is DatabaseError) {
      rethrow;
    } else {
      throw DatabaseError(e.toString());
    }
  } catch (e) {
    if (e is DatabaseError) {
      rethrow;
    } else {
      //devPrint(e);
      //devPrint(e.runtimeType);
      throw DatabaseError(e.toString());
    }
  }
}

//
// We no longer catch the native exception asynchronously
// as it makes the stack trace lost...
//
Future<T> catchAsyncNativeError<T>(Future<T> action()) {
  var result = catchNativeError(action);
  return result;
}
