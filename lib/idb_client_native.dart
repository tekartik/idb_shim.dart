library idb_native;

import 'dart:async';
import 'package:idb_shim/idb_client.dart';
import 'dart:indexed_db' as idb;
import 'dart:html' as html;

part 'src/native/native_event.dart';
part 'src/native/native_transaction.dart';
part 'src/native/native_database.dart';
part 'src/native/native_object_store.dart';
part 'src/native/native_cursor.dart';
part 'src/native/native_index.dart';
part 'src/native/native_key_range.dart';

class IdbNativeFactory extends IdbFactory {

  static IdbNativeFactory _instance;
  IdbNativeFactory._();

  String get name => IDB_FACTORY_NATIVE;
  
  factory IdbNativeFactory() {
    if (_instance == null) {
      _instance = new IdbNativeFactory._();
    }
    return _instance;
  }

  @override
  Future<Database> open(String dbName, {int version, OnUpgradeNeededFunction onUpgradeNeeded, OnBlockedFunction onBlocked}) {
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

    return html.window.indexedDB.open(dbName, version: version, onUpgradeNeeded: onUpgradeNeeded == null ? null : _onUpgradeNeeded, onBlocked: onBlocked == null && _onUpgradeNeeded == null ? null : _onBlocked).then((idb.Database database) {
      return new _NativeDatabase(database);
    });
  }



  @override
  Future<IdbFactory> deleteDatabase(String dbName, {void onBlocked(Event)}) {
    void _onBlocked(html.Event e) {
      print("blocked deleting $dbName");
      Event event = new _NativeEvent(e);
      onBlocked(event);
    }
    return html.window.indexedDB.deleteDatabase(dbName, onBlocked: onBlocked == null ? null : _onBlocked).then((_) {
      return this;
    });
  }

  @override
  bool get supportsDatabaseNames {

    return html.window.indexedDB.supportsDatabaseNames;
  }

  @override
  Future<List<String>> getDatabaseNames() {
    return html.window.indexedDB.getDatabaseNames();
  }

  static bool get supported {
    return idb.IdbFactory.supported;
  }
}
