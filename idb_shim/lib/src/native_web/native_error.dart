// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/native_web/js_utils.dart';
import 'indexed_db_web.dart' as idb;

@JS('Object.keys')
external JSArray _jsObjectKeys(JSAny object);

List<String> jsObjectKeys(JSAny object) =>
    _jsObjectKeys(object).toDart.cast<String>();

T catchNativeError<T>(T Function() action) {
  try {
    return action();
  } catch (e) {
    // Might throw before
    _handleError(e);
    rethrow;
  }
}

/// Should rethrow if the error was handled.
bool _handleError(Object e) {
  if (e is DatabaseError) {
    return false;
  } else if (e is DatabaseException) {
    return false;
  } else if (e is Error) {
    // Happens on wasm, very unfortunate
    // _JavascriptError
    // devPrint('error: ${Error.safeToString(e)}');
    throw DatabaseError(e.toString());
  } else {
    // Handle js error
    try {
      var error = e as JSError;
      throw DatabaseErrorNative(
          error.name ?? 'IDBError', error.message ?? e.toString());
    } catch (_) {
      // print('error: $_');
      throw DatabaseError(e.toString());
    }
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
    /// Might throw before
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
