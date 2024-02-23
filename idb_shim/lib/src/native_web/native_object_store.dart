// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/idb.dart';

import 'indexed_db_web.dart' as idb;
import 'native_error.dart';
import 'native_helpers.dart';
import 'native_index.dart';
import 'native_key_range.dart';

class ObjectStoreNative extends ObjectStore {
  idb.IDBObjectStore idbObjectStore;

  ObjectStoreNative(this.idbObjectStore);

  @override
  Index createIndex(String name, Object keyPath,
      {bool? unique, bool? multiEntry}) {
    /// Fix compilation using dart2js for keyPath array
    /// causing SyntaxError: Failed to execute 'createIndex' on 'IDBObjectStore': The keyPath argument contains an invalid key path.
    if (keyPath is Iterable) {
      keyPath = List<String>.from(keyPath);
    }
    return IndexNative(idbObjectStore.createIndex(
        name,
        keyPath.jsify()!,
        idb.IDBIndexParameters(
            unique: unique ?? false, multiEntry: multiEntry ?? false)));
  }

  @override
  void deleteIndex(String name) {
    catchNativeError(() {
      idbObjectStore.deleteIndex(name);
    });
  }

  @override
  Future<Object> add(Object value, [Object? key]) {
    return catchAsyncNativeError(() {
      var request = idbObjectStore.add(value.jsify(), key?.jsify());
      return request.future.then((value) => value!.dartify()!);
      //.then((key) => key as Object);
    });
  }

  // Not async please for ie!
  @override
  Future<Object?> getObject(Object key) {
    return catchAsyncNativeError(() {
      return idbObjectStore.get(key.jsify()).dartFutureNullable<Object?>();
    });
  }

  @override
  Future clear() {
    return catchAsyncNativeError(() {
      return idbObjectStore.clear().future;
    });
  }

  @override
  Future<Object> put(Object value, [Object? key]) {
    return catchAsyncNativeError(() {
      return idbObjectStore
          .put(value.jsify(), key?.jsify())
          .dartFuture<Object>();
    });
  }

  @override
  Future delete(Object? key) {
    return catchAsyncNativeError(() {
      return idbObjectStore.delete(key?.jsify()).future;
    });
  }

  @override
  Index index(String name) {
    return IndexNative(idbObjectStore.index(name));
  }

  @override
  Stream<CursorWithValue> openCursor(
      {Object? key, KeyRange? range, String? direction, bool? autoAdvance}) {
    var query = keyOrKeyRangeToNativeQuery(key: key, range: range);
    idb.IDBRequest request;
    if (query == null && direction == null) {
      request = idbObjectStore.openCursor();
    } else if (direction == null) {
      request = idbObjectStore.openCursor(query);
    } else {
      request = idbObjectStore.openCursor(query, direction);
    }
    return cursorWithValueStreamFromResult(request, autoAdvance);
  }

  @override
  Stream<Cursor> openKeyCursor(
      {Object? key, KeyRange? range, String? direction, bool? autoAdvance}) {
    var query = keyOrKeyRangeToNativeQuery(key: key, range: range);
    idb.IDBRequest request;
    if (query == null && direction == null) {
      request = idbObjectStore.openKeyCursor();
    } else if (direction == null) {
      request = idbObjectStore.openKeyCursor(query);
    } else {
      request = idbObjectStore.openKeyCursor(query, direction);
    }
    return cursorWithValueStreamFromResult(request, autoAdvance);
  }

  @override
  Future<int> count([dynamic keyOrRange]) {
    return catchAsyncNativeError(() {
      Future<int> countFuture;
      if (keyOrRange == null) {
        countFuture = idbObjectStore.count().dartFuture<int>();
      } else {
        countFuture =
            idbObjectStore.count(toNativeQuery(keyOrRange)).dartFuture<int>();
      }
      return countFuture;
    });
  }

  @override
  Future<List<Object>> getAll([Object? query, int? count]) {
    return catchAsyncNativeError(() {
      final nativeQuery = toNativeQuery(query);
      var results = storeGetAll(idbObjectStore, nativeQuery, count);
      return results;
    });
  }

  @override
  Future<List<Object>> getAllKeys([dynamic query, int? count]) {
    return catchAsyncNativeError(() {
      final nativeQuery = toNativeQuery(query);
      var results = storeGetAllKeys(idbObjectStore, nativeQuery, count);
      return results;
    });
  }

  @override
  Object? get keyPath => idbObjectStore.keyPath;

  // ie return null so make sure it is a bool
  @override
  bool get autoIncrement => idbObjectStore.autoIncrement;

  @override
  String get name => idbObjectStore.name;

  @override
  List<String> get indexNames => idbObjectStore.indexNames.toStringList();
}
