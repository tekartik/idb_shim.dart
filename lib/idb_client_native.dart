library idb_shim_native;

import 'dart:async';
import 'dart:html' as html;
import 'dart:html_common' as html_common;
import 'dart:indexed_db' as idb;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_factory.dart';

import 'src/utils/browser_utils.dart';

part 'src/native/native_cursor.dart';

part 'src/native/native_database.dart';

part 'src/native/native_error.dart';

part 'src/native/native_event.dart';
part 'src/native/native_index.dart';
part 'src/native/native_key_range.dart';

part 'src/native/native_object_store.dart';

part 'src/native/native_transaction.dart';

IdbNativeFactory get idbNativeFactory => new IdbNativeFactory();

class IdbNativeFactory extends IdbFactoryBase {
  @override
  bool get persistent => true;

  static IdbNativeFactory _instance;
  IdbNativeFactory._();

  String get name => idbFactoryNative;

  factory IdbNativeFactory() {
    if (_instance == null) {
      _instance = new IdbNativeFactory._();
    }
    return _instance;
  }

  @override
  Future<Database> open(String dbName,
      {int version,
      OnUpgradeNeededFunction onUpgradeNeeded,
      OnBlockedFunction onBlocked}) {
    void _onUpgradeNeeded(idb.VersionChangeEvent e) {
      _NativeVersionChangeEvent event = new _NativeVersionChangeEvent(e);
      onUpgradeNeeded(event);
    }

    void _onBlocked(html.Event e) {
      if (onBlocked != null) {
        Event event = new _NativeEvent(e);
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
      return new _NativeDatabase(database);
    });
  }

  @override
  Future<IdbFactory> deleteDatabase(String dbName,
      {OnBlockedFunction onBlocked}) {
    void _onBlocked(html.Event e) {
      print("blocked deleting $dbName");
      Event event = new _NativeEvent(e);
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
    throw new DatabaseException('getDatabaseNames not supported');
  }

  static bool get supported {
    return idb.IdbFactory.supported;
  }

  @override
  int cmp(Object first, Object second) {
    return _catchNativeError(() => html.window.indexedDB.cmp(first, second));
  }
}
