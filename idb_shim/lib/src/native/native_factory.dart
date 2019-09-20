import 'dart:async';
import 'dart:html' as html;
import 'dart:indexed_db' as idb;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/native/native_compat.dart';
import 'package:idb_shim/src/native/native_database.dart';
import 'package:idb_shim/src/native/native_error.dart';
import 'package:idb_shim/src/native/native_event.dart';
import 'package:idb_shim/src/utils/browser_utils.dart';
import 'package:idb_shim/src/utils/value_utils.dart';

IdbFactory _idbFactoryNativeImpl;
IdbFactory get idbFactoryNativeImpl => _idbFactoryNativeImpl ??= () {
      if (!IdbFactoryNativeImpl.supported) {
        return null;
      }
      return IdbFactoryNativeImpl();
    }();

class IdbFactoryNativeImpl extends IdbFactoryBase
    implements
        // ignore: deprecated_member_use_from_same_package
        IdbNativeFactory,
        // ignore: deprecated_member_use_from_same_package
        IdbFactoryNative {
  @override
  bool get persistent => true;

  static IdbFactoryNativeImpl _instance;

  IdbFactoryNativeImpl._();

  @override
  String get name => idbFactoryNameNative;

  factory IdbFactoryNativeImpl() {
    if (_instance == null) {
      _instance = IdbFactoryNativeImpl._();
    }
    return _instance;
  }

  @override
  Future<Database> open(String dbName,
      {int version,
      OnUpgradeNeededFunction onUpgradeNeeded,
      OnBlockedFunction onBlocked}) {
    void _onUpgradeNeeded(idb.VersionChangeEvent e) {
      VersionChangeEventNative event = VersionChangeEventNative(e);
      onUpgradeNeeded(event);
    }

    void _onBlocked(html.Event e) {
      if (onBlocked != null) {
        Event event = EventNative(e);
        onBlocked(event);
      } else {
        print("blocked opening $dbName v $version");
      }
    }

    return html.window.indexedDB
        .open(dbName,
            version: version,
            onUpgradeNeeded: onUpgradeNeeded == null ? null : _onUpgradeNeeded,
            onBlocked: onBlocked == null && _onUpgradeNeeded == null
                ? null
                : _onBlocked)
        .then((idb.Database database) {
      return DatabaseNative(database);
    });
  }

  @override
  Future<IdbFactory> deleteDatabase(String dbName,
      {OnBlockedFunction onBlocked}) {
    void _onBlocked(html.Event e) {
      print("blocked deleting $dbName");
      Event event = EventNative(e);
      onBlocked(event);
    }

    return html.window.indexedDB
        .deleteDatabase(dbName,
            onBlocked: onBlocked == null ? null : _onBlocked)
        .then((_) {
      return this;
    });
  }

  @override
  bool get supportsDatabaseNames {
    return html.window.indexedDB.supportsDatabaseNames;
  }

  @override
  Future<List<String>> getDatabaseNames() {
    // ignore: undefined_method
    throw DatabaseException('getDatabaseNames not supported');
  }

  static bool get supported {
    return idb.IdbFactory.supported;
  }

  @override
  int cmp(Object first, Object second) {
    return catchNativeError(() {
      if (first is List && (isIe || isEdge)) {
        return greaterThan(first, second)
            ? 1
            : (lessThan(first, second) ? -1 : 0);
      } else {
        return html.window.indexedDB.cmp(first, second);
      }
    });
  }

  @override
  bool get supportsDoubleKey => false;
}
