import 'dart:async';

import 'package:idb_shim/idb.dart';

//bool dev = true;

T? catchNativeError<T>(T Function() action) {
  try {
    return action();
  } catch (e) {
    if (!_handleError(e)) {
      rethrow;
    }
    // We should never get there
    return null;
  }
}

bool _handleError(dynamic e) {
  if (e is DatabaseError) {
    return false;
  } else if (e is DatabaseException) {
    return false;
  } else {
    throw DatabaseError(e.toString());
  }
}

//
// We no longer catch the native exception asynchronously
// as it makes the stack trace lost...
//
Future<T?> catchAsyncNativeError<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    if (!_handleError(e)) {
      rethrow;
    }
    // We should never get there
    return null;
  }
}
