// ignore_for_file: public_member_api_docs

import 'dart:js_interop';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/utils/browser_utils.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:idb_shim/src/utils/value_utils.dart';

import 'indexed_db_web.dart' as idb;
import 'indexed_db_web.dart' as native;
import 'native_database.dart';
import 'native_error.dart';
import 'native_event.dart';

IdbFactory? _idbFactoryNativeBrowserImpl;

IdbFactory get idbFactoryNativeBrowserImpl =>
    _idbFactoryNativeBrowserImpl ??= () {
      return nativeIdbFactoryBrowserWrapperImpl;
    }();

native.IDBFactory? get nativeBrowserIdbFactory => idb.window.indexedDB;

// Single instance
IdbFactoryNativeBrowserWrapperImpl? _nativeIdbFactoryBrowserWrapperImpl;

IdbFactoryNativeBrowserWrapperImpl get nativeIdbFactoryBrowserWrapperImpl =>
    _nativeIdbFactoryBrowserWrapperImpl ??=
        IdbFactoryNativeBrowserWrapperImpl._();

/// Browser only
class IdbFactoryNativeBrowserWrapperImpl extends IdbFactoryNativeWrapperImpl {
  IdbFactoryNativeBrowserWrapperImpl._() : super(nativeBrowserIdbFactory!);

  static bool get supported {
    return idb.IDBFactoryExt.supported;
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
  Future<Database> open(String dbName,
      {int? version,
      OnUpgradeNeededFunction? onUpgradeNeeded,
      OnBlockedFunction? onBlocked}) {
    if ((version == null) != (onUpgradeNeeded == null)) {
      throw ArgumentError(
          'version and onUpgradeNeeded must be specified together');
    }
    var completer = Completer<JSAny>.sync();
    idb.IDBOpenDBRequest openRequest;
    if (version != null) {
      openRequest = nativeFactory.open(dbName, version);
    } else {
      openRequest = nativeFactory.open(dbName);
    }
    if (onBlocked != null) {
      openRequest.onblocked = (idb.Event event) {
        onBlocked(EventNative(event));
      }.toJS;
    }
    if (onUpgradeNeeded != null) {
      openRequest.onupgradeneeded = (idb.IDBVersionChangeEvent event) {
        onUpgradeNeeded(VersionChangeEventNative(this, event));
      }.toJS;
    }
    openRequest.handleOnSuccessAndError(completer);
    return completer.future.then(
        (value) => DatabaseNative(this, openRequest.result as idb.IDBDatabase));
  }

  @override
  Future<IdbFactory> deleteDatabase(String dbName,
      {OnBlockedFunction? onBlocked}) {
    var completer = Completer<JSAny?>.sync();
    var deleteRequest = nativeFactory.deleteDatabase(dbName);
    if (onBlocked != null) {
      deleteRequest.onblocked = (idb.Event event) {
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
      if (first is List && (isIe || isEdge)) {
        return greaterThan(first, second)
            ? 1
            : (lessThan(first, second) ? -1 : 0);
      } else {
        return nativeFactory.cmp(first.jsify(), second.jsify());
      }
    })!;
  }

  @override
  bool get supportsDoubleKey => false;
}
