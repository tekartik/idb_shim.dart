import 'dart:async';
import 'dart:html' as html;
import 'dart:indexed_db' as idb;
import 'dart:indexed_db' as native;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/native/native_compat.dart';
import 'package:idb_shim/src/native/native_database.dart';
import 'package:idb_shim/src/native/native_error.dart';
import 'package:idb_shim/src/native/native_event.dart';
import 'package:idb_shim/src/utils/browser_utils.dart';
import 'package:idb_shim/src/utils/value_utils.dart';

IdbFactory? _idbFactoryNativeBrowserImpl;
IdbFactory get idbFactoryNativeBrowserImpl =>
    _idbFactoryNativeBrowserImpl ??= () {
      return nativeIdbFactoryBrowserWrapperImpl;
    }();

native.IdbFactory? get nativeBrowserIdbFactory => html.window.indexedDB;

// Single instance
IdbFactoryNativeBrowserWrapperImpl? _nativeIdbFactoryBrowserWrapperImpl;
IdbFactoryNativeBrowserWrapperImpl get nativeIdbFactoryBrowserWrapperImpl =>
    _nativeIdbFactoryBrowserWrapperImpl ??=
        IdbFactoryNativeBrowserWrapperImpl._();

/// Browser only
class IdbFactoryNativeBrowserWrapperImpl extends IdbFactoryNativeWrapperImpl {
  IdbFactoryNativeBrowserWrapperImpl._() : super(nativeBrowserIdbFactory!);

  static bool get supported {
    return idb.IdbFactory.supported;
  }
}

/// Wrapper for window.indexedDB and worker self.indexedDB
class IdbFactoryNativeWrapperImpl extends IdbFactoryBase
    implements
        // ignore: deprecated_member_use_from_same_package
        IdbNativeFactory,
        // ignore: deprecated_member_use_from_same_package
        IdbFactoryNative {
  final native.IdbFactory nativeFactory;

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
    void _onUpgradeNeeded(idb.VersionChangeEvent e) {
      final event = VersionChangeEventNative(this, e);
      onUpgradeNeeded!(event);
    }

    void _onBlocked(html.Event e) {
      if (onBlocked != null) {
        Event event = EventNative(e);
        onBlocked(event);
      } else {
        print('blocked opening $dbName v $version');
      }
    }

    return nativeFactory
        .open(dbName,
            version: version,
            onUpgradeNeeded: onUpgradeNeeded == null ? null : _onUpgradeNeeded,
            onBlocked: onBlocked == null && onUpgradeNeeded == null
                ? null
                : _onBlocked)
        .then((idb.Database database) {
      return DatabaseNative(this, database);
    });
  }

  @override
  Future<IdbFactory> deleteDatabase(String dbName,
      {OnBlockedFunction? onBlocked}) {
    void _onBlocked(html.Event e) {
      print('blocked deleting $dbName');
      Event event = EventNative(e);
      onBlocked!(event);
    }

    return nativeFactory
        .deleteDatabase(dbName,
            onBlocked: onBlocked == null ? null : _onBlocked)
        .then((_) {
      return this;
    });
  }

  @override
  bool get supportsDatabaseNames {
    return nativeFactory.supportsDatabaseNames;
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
        return nativeFactory.cmp(first, second);
      }
    })!;
  }

  @override
  bool get supportsDoubleKey => false;
}
