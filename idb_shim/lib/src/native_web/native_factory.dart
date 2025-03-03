// ignore_for_file: public_member_api_docs

import 'dart:js_interop';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/native_web/js_utils.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import 'indexed_db_web.dart' as idb;
import 'indexed_db_web.dart' as native;
import 'indexed_db_web.dart';
import 'native_database.dart';
import 'native_error.dart';
import 'native_event.dart';

/// Single instance
final IdbFactory idbFactoryBrowserWrapperImpl =
    IdbFactoryNativeBrowserWrapperImpl._();

final IdbFactory idbFactoryWebWorkerWrapperImpl =
    IdbFactoryWebWorkerWrapperImpl._();

/// Browser only
class IdbFactoryNativeBrowserWrapperImpl extends IdbFactoryNativeWrapperImpl {
  IdbFactoryNativeBrowserWrapperImpl._() : super(nativeBrowserIdbFactory!);

  static bool get supported {
    return idb.IDBFactoryExt.supported;
  }
}

/// Browser only
class IdbFactoryWebWorkerWrapperImpl extends IdbFactoryNativeWrapperImpl {
  IdbFactoryWebWorkerWrapperImpl._() : super(nativeWebWorkerIdbFactory!);
  static bool get supported {
    try {
      nativeWebWorkerIdbFactory!;
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Wrapper for window.indexedDB and worker self.indexedDB
class IdbFactoryNativeWrapperImpl extends IdbFactoryBase {
  final native.IDBFactory nativeFactory;

  @override
  bool get persistent => true;

  IdbFactoryNativeWrapperImpl(this.nativeFactory);

  @override
  String get name => idbFactoryNameNative;

  @override
  Future<Database> open(
    String dbName, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) async {
    if ((version == null) != (onUpgradeNeeded == null)) {
      throw ArgumentError(
        'version and onUpgradeNeeded must be specified together',
      );
    }
    var completer = Completer<JSAny>.sync();
    idb.IDBOpenDBRequest openRequest;
    if (version != null) {
      openRequest = nativeFactory.open(dbName, version);
    } else {
      openRequest = nativeFactory.open(dbName);
    }
    if (onBlocked != null) {
      openRequest.onblocked =
          (idb.Event event) {
            onBlocked(EventNative(event));
          }.toJS;
    }
    FutureOr? onUpdateNeededFutureOr;
    Object? onUpdateNeededException;
    if (onUpgradeNeeded != null) {
      EventStreamProviders.upgradeNeededEvent.forTarget(openRequest).listen((
        idb.IDBVersionChangeEvent event,
      ) {
        try {
          onUpdateNeededFutureOr = onUpgradeNeeded(
            VersionChangeEventNative(this, event),
          );
        } catch (e) {
          onUpdateNeededException = e;
        }
      });
    }
    openRequest.handleOnSuccessAndError(completer);
    await completer.future;

    /// Wait on onUpgradeNeeded to complete.
    if (onUpdateNeededFutureOr is Future && onUpdateNeededException == null) {
      try {
        await onUpdateNeededFutureOr;
      } catch (e) {
        onUpdateNeededException = e;
      }
    }
    var idbDatabase = openRequest.result as idb.IDBDatabase;
    if (onUpdateNeededException != null) {
      idbDatabase.close();
      throw onUpdateNeededException!;
    }

    return DatabaseNative(this, idbDatabase);
  }

  @override
  Future<IdbFactory> deleteDatabase(
    String dbName, {
    OnBlockedFunction? onBlocked,
  }) {
    var completer = Completer<JSAny?>.sync();
    var deleteRequest = nativeFactory.deleteDatabase(dbName);
    if (onBlocked != null) {
      deleteRequest.onblocked =
          (idb.Event event) {
            onBlocked(EventNative(event));
          }.toJS;
    }
    deleteRequest.handleOnSuccessAndError(completer);
    return completer.future.then((_) => this);
  }

  @override
  bool get supportsDatabaseNames {
    // No longer supported on modern browsers. Always returns false
    return false;
  }

  @override
  Future<List<String>> getDatabaseNames() {
    // ignore: undefined_method
    throw DatabaseException('getDatabaseNames not supported');
  }

  @override
  int cmp(Object first, Object second) {
    return catchNativeError(() {
      return nativeFactory.cmp(first.jsifyKey(), second.jsifyKey());
    })!;
  }

  @override
  bool get supportsDoubleKey => false;
}

/// WebWorker factory
final _workerScope = (globalContext as native.DedicatedWorkerGlobalScope?);

/// Worker native IDBFactory
native.IDBFactory? get nativeWebWorkerIdbFactory => _workerScope?.indexedDB;

/// Native browser IDBFactory
native.IDBFactory? get nativeBrowserIdbFactory => idb.window.indexedDB;

// // var
// final _store = 'values';
// var _database = () async {
//   // var factory = idbFactoryFromIndexedDB(scope.indexedDB);
