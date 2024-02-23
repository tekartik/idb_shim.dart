import 'dart:js_interop';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/native_web/native_cursor.dart';
import 'package:idb_shim/src/native_web/native_key_range.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import 'indexed_db_web.dart' as idb;
import 'native_error.dart';

///
/// Helper for iterating over cursors in a request.
///
/// Copied from dart sdk
///
Stream<Cursor> cursorStreamFromResult(
    idb.IDBRequest request, bool? autoAdvance) {
// TODO: need to guarantee that the controller provides the values
// immediately as waiting until the next tick will cause the transaction to
// close.
  var controller = StreamController<Cursor>(sync: true);

//TODO: Report stacktrace once issue 4061 is resolved.
  request.onerror = (idb.Event event) {
    controller.addError(DatabaseErrorNative.domException(request.error!));
  }.toJS;

  request.onsuccess = (idb.Event event) {
    var cursor = request.result as idb.IDBCursor?;
    if (cursor == null) {
      controller.close();
    } else {
      controller.add(CursorNative(cursor));
      if (autoAdvance == true && controller.hasListener) {
        cursor.continue_();
      }
    }
  }.toJS;
  return controller.stream;
}

///
/// Helper for iterating over cursors in a request.
///
/// Copied from dart sdk
///
Stream<CursorWithValue> cursorWithValueStreamFromResult(
    idb.IDBRequest request, bool? autoAdvance) {
  // TODO: need to guarantee that the controller provides the values
  // immediately as waiting until the next tick will cause the transaction to
  // close.
  var controller = StreamController<CursorWithValue>(sync: true);

  request.onerror = (idb.Event event) {
    controller.addError(DatabaseErrorNative.domException(request.error!));
  }.toJS;

  request.onsuccess = (idb.Event event) {
    var cursor = request.result as idb.IDBCursorWithValue?;
    if (cursor == null) {
      controller.close();
    } else {
      controller.add(CursorWithValueNative(cursor));
      if (autoAdvance == true && controller.hasListener) {
        cursor.continue_();
      }
    }
  }.toJS;
  return controller.stream;
}

///
/// Creates a stream of cursors over the records in this object store.
///
Stream<Cursor> storeOpenKeyCursor(idb.IDBObjectStore objectStore,
    {Object? key, KeyRange? range, String? direction, bool? autoAdvance}) {
  dynamic keyOrRange;
  if (key != null) {
    if (range != null) {
      throw ArgumentError('Cannot specify both key and range.');
    }
    keyOrRange = key;
  } else {
    keyOrRange = range;
  }
  idb.IDBRequest request;
  if (direction == null) {
    // FIXME: Passing in 'next' should be unnecessary.
    request = objectStore.openKeyCursor(toNativeQuery(keyOrRange), 'next');
  } else {
    request = objectStore.openKeyCursor(toNativeQuery(keyOrRange), direction);
  }
  return cursorStreamFromResult(request, autoAdvance);
}

///
/// [query] is a native query
///
Future<List<Object>> storeGetAll(idb.IDBObjectStore objectStore,
    [dynamic query, int? count]) async {
  return catchAsyncNativeError(() {
    idb.IDBRequest request;
    if (count != null) {
      request = objectStore.getAll(toNativeQuery(query), count);
    } else {
      request = objectStore.getAll(toNativeQuery(query));
    }
    return request.dartFutureList<Object>();
  });
}

///
/// [query] is a native query
///
Future<List<Object>> storeGetAllKeys(idb.IDBObjectStore objectStore,
    [Object? query, int? count]) async {
  return catchAsyncNativeError(() {
    idb.IDBRequest request;
    if (count != null) {
      request = objectStore.getAllKeys(toNativeQuery(query), count);
    } else {
      request = objectStore.getAllKeys(toNativeQuery(query));
    }
    return request.dartFutureList<Object>();
  });
}

///
/// [query] is a native query
///
Future<List<Object>> indexGetAll(idb.IDBIndex index,
    [Object? query, int? count]) {
  return catchAsyncNativeError(() {
    idb.IDBRequest request;
    if (count != null) {
      request = index.getAll(toNativeQuery(query), count);
    } else {
      request = index.getAll(toNativeQuery(query));
    }
    return request.dartFutureList<Object>();
  });
}

///
/// [query] is a native query
///
Future<List<Object>> indexGetAllKeys(idb.IDBIndex index,
    [Object? query, int? count]) {
  return catchAsyncNativeError(() {
    idb.IDBRequest request;
    if (count != null) {
      request = index.getAllKeys(toNativeQuery(query), count);
    } else {
      request = index.getAllKeys(toNativeQuery(query));
    }
    return request.dartFutureList<Object>();
  });
}
