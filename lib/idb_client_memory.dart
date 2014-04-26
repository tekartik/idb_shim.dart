library idb_memory;

import 'dart:async';
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_key_range.dart';
import 'package:idb_shim/src/common/common_value.dart';

part 'src/memory/memory_cursor.dart';
part 'src/memory/memory_item.dart';
part 'src/memory/memory_index.dart';
part 'src/memory/memory_object_store.dart';
part 'src/memory/memory_transaction.dart';
part 'src/memory/memory_database.dart';
part 'src/memory/memory_error.dart';

class IdbMemoryFactory extends IdbFactory {

  Map<String, _MemoryDatabaseData> dbMap = new Map();

  static IdbMemoryFactory _instance;
  IdbMemoryFactory._();

  String get name => IDB_FACTORY_MEMORY;
  
  factory IdbMemoryFactory() {
    if (_instance == null) {
      _instance = new IdbMemoryFactory._();
    }
    return _instance;
  }

  @override
  Future<Database> open(String dbName, {int version, OnUpgradeNeededFunction onUpgradeNeeded, OnBlockedFunction onBlocked}) {

    // check params
    if ((version == null) != (onUpgradeNeeded == null)) {
      return new Future.error(new ArgumentError('version and onUpgradeNeeded must be specified together'));
    }
    if (version == 0) {
      return new Future.error(new ArgumentError('version cannot be 0'));
    } else if (version == null) {
      version = 1;
    }

    // name null no
    if (dbName == null) {
      return new Future.error(new ArgumentError('name cannot be null'));
    }

    _MemoryDatabaseData foundData = dbMap[dbName];
    _MemoryDatabase db = new _MemoryDatabase(this, dbName, foundData);
    if (foundData == null) {
      dbMap[dbName] = db._data;
    }

    return db.open(version, onUpgradeNeeded).then((_) {
      return db;
    });

  }

  Future<IdbFactory> deleteDatabase(String dbName, {void onBlocked(Event)}) {
    if (dbName == null) {
      return new Future.error(new ArgumentError('dbName cannot be null'));
    }
    dbMap.remove(dbName);
    return new Future.value(this);
  }

  @override
  bool get supportsDatabaseNames {
    return true;
  }

  Future<List<String>> getDatabaseNames() {
    return new Future.value(dbMap.keys.toList(growable: false));
  }
}
