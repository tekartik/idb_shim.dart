// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/idb.dart';
import 'indexed_db_web.dart' as idb;

@JS('Object.keys')
external JSArray _jsObjectKeys(JSAny object);
List<String> jsObjectKeys(JSAny object) =>
    _jsObjectKeys(object).toDart.cast<String>();

T catchNativeError<T>(T Function() action) {
  try {
    return action();
  } catch (e) {
    _handleError(e);
    rethrow;
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
Future<T> catchAsyncNativeError<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    _handleError(e);
    rethrow;
  }
}

class DatabaseErrorNative extends DatabaseError {
  final String name;

  DatabaseErrorNative(this.name, String message) : super(message);
  DatabaseErrorNative.domException(idb.DOMException exception)
      : name = exception.name,
        super(exception.message);

  @override
  StackTrace? get stackTrace => null;

  @override
  String toString() => '$name: $message';
}
