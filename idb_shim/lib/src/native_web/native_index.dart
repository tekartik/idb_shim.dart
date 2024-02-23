// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/idb.dart';

import 'indexed_db_web.dart' as idb;
import 'native_error.dart';
import 'native_helpers.dart';
import 'native_key_range.dart';

class IndexNative extends Index {
  idb.IDBIndex idbIndex;

  IndexNative(this.idbIndex);

  @override
  Future<Object?> get(Object? key) {
    return catchAsyncNativeError(() {
      return idbIndex.get(key?.jsify()).dartFutureNullable<Object?>();
    });
  }

  @override
  Future<Object?> getKey(Object? key) {
    return catchAsyncNativeError(() {
      return idbIndex.getKey(key?.jsify()).dartFutureNullable<Object?>();
    });
  }

  @override
  Future<int> count([keyOrRange]) {
    Future<int> countFuture;
    return catchAsyncNativeError(() {
      if (keyOrRange == null) {
        countFuture = idbIndex.count().dartFuture<int>();
      } else {
        countFuture =
            idbIndex.count(toNativeQuery(keyOrRange)).dartFuture<int>();
      }
      return countFuture;
    });
  }

  @override
  Stream<Cursor> openKeyCursor(
      {key, KeyRange? range, String? direction, bool? autoAdvance}) {
    var query = keyOrKeyRangeToNativeQuery(key: key, range: range);
    idb.IDBRequest request;
    if (query == null && direction == null) {
      request = idbIndex.openKeyCursor();
    } else if (direction == null) {
      request = idbIndex.openKeyCursor(query);
    } else {
      request = idbIndex.openKeyCursor(query, direction);
    }
    return cursorWithValueStreamFromResult(request, autoAdvance);
  }

  /// Same implementation than for the Store
  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange? range, String? direction, bool? autoAdvance}) {
    var query = keyOrKeyRangeToNativeQuery(key: key, range: range);
    idb.IDBRequest request;
    if (query == null && direction == null) {
      request = idbIndex.openCursor();
    } else if (direction == null) {
      request = idbIndex.openCursor(query);
    } else {
      request = idbIndex.openCursor(query, direction);
    }
    return cursorWithValueStreamFromResult(request, autoAdvance);
  }

  @override
  Future<List<Object>> getAll([Object? query, int? count]) {
    return catchAsyncNativeError(() {
      final nativeQuery = toNativeQuery(query);
      var results = indexGetAll(idbIndex, nativeQuery, count);
      return results;
    });
  }

  @override
  Future<List<Object>> getAllKeys([Object? query, int? count]) {
    return catchAsyncNativeError(() {
      final nativeQuery = toNativeQuery(query);
      var results = indexGetAllKeys(idbIndex, nativeQuery, count);
      return results;
    });
  }

  @override
  Object get keyPath => idbIndex.keyPath as Object;

  @override
  bool get unique => idbIndex.unique;

  @override
  bool get multiEntry => idbIndex.multiEntry;

  @override
  int get hashCode => idbIndex.hashCode;

  @override
  String get name => idbIndex.name;

  @override
  bool operator ==(other) {
    if (other is IndexNative) {
      return idbIndex == other.idbIndex;
    }
    return false;
  }
}
