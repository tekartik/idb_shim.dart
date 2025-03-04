import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/src/native_web/js_utils.dart';
import 'package:idb_shim/src/native_web/native_error.dart';
import 'package:web/web.dart';

export 'package:web/web.dart'
    show
        window,
        IDBRequest,
        IDBOpenDBRequest,
        Event,
        IDBDatabase,
        IDBTransaction,
        IDBVersionChangeEvent,
        IDBObjectStore,
        IDBObjectStoreParameters,
        IDBCursor,
        IDBCursorWithValue,
        IDBIndex,
        IDBIndexParameters,
        IDBKeyRange,
        IDBFactory,
        DOMException,
        EventStreamProviders,
        WorkerGlobalScope;

/// IDB upgrade needed event
extension type IDBOnUpgradeNeededEvent._(JSObject _)
    implements IDBVersionChangeEvent {
  external IDBOpenEventTarget get target;
}

/// IDB open event target
extension type IDBOpenEventTarget._(JSObject _) implements EventTarget {
  /// Resulting database
  external IDBDatabase get result;
}

/// IDB open success event
extension type IDBOnOpenSuccessEvent._(JSObject _) implements Event {
  /// Open event target
  external IDBRequest get target;
}

/// IDB request event target
extension type IDBRequestEventTarget._(JSObject _) implements EventTarget {
  /// Result
  external JSAny get result;
}

/// IDB request event
extension type IDBRequestEvent._(JSObject _) implements Event {
  /// Request event target
  external IDBRequestEventTarget get target;
}

/// DOMStringList extension.
extension DOMStringListExt on DOMStringList {
  /// Convert to iterable
  Iterable<String> toStringIterable() =>
      Iterable.generate(length, (i) => item(i)!);

  /// Convert to list
  List<String> toStringList() => List.generate(length, (i) => item(i)!);
}

/// IDB request helper
extension IDBRequestExt on IDBRequest {
  /// On error helper.
  void handleOnError(Completer<JSAny?> completer) {
    onerror =
        (Event event) {
          if (!completer.isCompleted) {
            completer.completeError(DatabaseErrorNative.domException(error!));
          }
        }.toJS;
  }

  /*
  /// Handle on abort
  void handleOnAbort(Completer<JSAny?> completer) {
    onabort = (Event event) {
      if (!completer.isCompleted) {
        completer.completeError(DatabaseErrorNative.domException(error!));
      }
    }.toJS;
  }*/

  /// On success helper.
  void handleOnSuccess(Completer<JSAny?> completer) {
    onsuccess =
        (Event event) {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        }.toJS;
  }

  /// On success and error helper.
  void handleOnSuccessAndError(Completer<JSAny?> completer) {
    handleOnSuccess(completer);
    handleOnError(completer);
  }

  /// Future result
  Future<JSAny?> get future {
    var completer = Completer<JSAny?>.sync();
    handleOnSuccessAndError(completer);
    return completer.future;
  }

  /// Dart future nullable.
  Future<T> dartFutureNullable<T extends Object?>() =>
      future.then((value) => value?.dartifyValue() as T);

  /// Dart future.
  Future<T> dartFuture<T extends Object>() =>
      future.then((value) => value!.dartifyValue() as T);

  /// Dart future list.
  Future<List<T>> dartFutureList<T extends Object?>() =>
      future.then((value) => (value!.dartifyValue() as List).cast<T>());
}

/// Compat
extension IDBFactoryExt on IDBFactory {
  /// True if native factory is supported
  static bool get supported {
    try {
      window.indexedDB;
      return true;
    } catch (_) {
      return false;
    }
  }
}
