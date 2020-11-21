@JS()
library idb_shim.native_interop;

import 'dart:indexed_db' as idb;

import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:js/js.dart';

///
/// Helper for iterating over cursors in a request.
///
/// Copied from dart sdk
///
Stream<idb.Cursor> cursorStreamFromResult(
    idb.Request request, bool? autoAdvance) {
// TODO: need to guarantee that the controller provides the values
// immediately as waiting until the next tick will cause the transaction to
// close.
  var controller = StreamController<idb.Cursor>(sync: true);

//TODO: Report stacktrace once issue 4061 is resolved.
  request.onError.listen(controller.addError);

  request.onSuccess.listen((e) {
    var cursor = request.result as idb.Cursor?;
    if (cursor == null) {
      controller.close();
    } else {
      controller.add(cursor);
      if (autoAdvance == true && controller.hasListener) {
        cursor.next();
      }
    }
  });
  return controller.stream;
}

///
/// Creates a stream of cursors over the records in this object store.
///
Stream<idb.Cursor> storeOpenKeyCursor(idb.ObjectStore objectStore,
    {dynamic key, idb.KeyRange? range, String? direction, bool? autoAdvance}) {
  var keyOrRange;
  if (key != null) {
    if (range != null) {
      throw ArgumentError('Cannot specify both key and range.');
    }
    keyOrRange = key;
  } else {
    keyOrRange = range;
  }
  idb.Request request;
  if (direction == null) {
    // FIXME: Passing in 'next' should be unnecessary.
    request = objectStore.openKeyCursor(keyOrRange, 'next');
  } else {
    request = objectStore.openKeyCursor(keyOrRange, direction);
  }
  return cursorStreamFromResult(request, autoAdvance);
}

// Ties a request to a completer, so the completer is completed when it succeeds
// and errors out when the request errors.

Future<T> _completeRequest<T>(idb.Request request) {
  var completer = Completer<T>.sync();
  // TODO: make sure that completer.complete is synchronous as transactions
  // may be committed if the result is not processed immediately.
  request.onSuccess.listen((e) {
    var result = request.result as T?;
    completer.complete(result);
  });
  request.onError.listen(completer.completeError);
  return completer.future;
}

///
/// [query] is a native query
///
Future<List<dynamic>> storeGetAll(idb.ObjectStore objectStore,
    [dynamic query, int? count]) async {
  try {
    idb.Request request;
    if (count != null) {
      request = objectStore.getAll(query, count);
    } else {
      request = objectStore.getAll(query);
    }
    return _completeRequest(request);
  } catch (e, stacktrace) {
    return Future.error(e, stacktrace);
  }
}

///
/// [query] is a native query
///
Future<List<dynamic>> storeGetAllKeys(idb.ObjectStore objectStore,
    [dynamic query, int? count]) async {
  try {
    idb.Request request;
    if (count != null) {
      request = objectStore.getAllKeys(query, count);
    } else {
      request = objectStore.getAllKeys(query);
    }
    return _completeRequest(request);
  } catch (e, stacktrace) {
    return Future.error(e, stacktrace);
  }
}

///
/// [query] is a native query
///
Future<List<dynamic>> indexGetAll(idb.Index index,
    [dynamic query, int? count]) async {
  try {
    idb.Request request;
    if (count != null) {
      request = index.getAll(query, count);
    } else {
      request = index.getAll(query);
    }
    return _completeRequest(request);
  } catch (e, stacktrace) {
    return Future.error(e, stacktrace);
  }
}

///
/// [query] is a native query
///
Future<List<dynamic>> indexGetAllKeys(idb.Index index,
    [dynamic query, int? count]) async {
  try {
    idb.Request request;
    if (count != null) {
      request = index.getAllKeys(query, count);
    } else {
      request = index.getAllKeys(query);
    }
    return _completeRequest(request);
  } catch (e, stacktrace) {
    return Future.error(e, stacktrace);
  }
}
