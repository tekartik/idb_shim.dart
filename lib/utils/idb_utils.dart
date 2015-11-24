library idb_shim.utils.idb_utils;

import '../idb_client.dart';
import 'dart:async';
import '../src/common/common_meta.dart';

class _SchemaMeta {
  List<IdbObjectStoreMeta> stores = [];
}

///
/// Copy a database to another
/// return the opened database
///
Future<Database> copySchema(
    Database srcDatabase, IdbFactory dstFactory, String dstDbName) async {
  // Delete the existing
  if (dstDbName != null) {
    await dstFactory.deleteDatabase(dstDbName);
  }

  int version = srcDatabase.version;

  _SchemaMeta schemaMeta = new _SchemaMeta();
  // Get schema
  List<String> storeNames = new List.from(srcDatabase.objectStoreNames);
  if (storeNames.isNotEmpty) {
    Transaction txn = srcDatabase.transactionList(storeNames, idbModeReadOnly);
    for (String storeName in storeNames) {
      ObjectStore store = txn.objectStore(storeName);
      IdbObjectStoreMeta storeMeta =
          new IdbObjectStoreMeta.fromObjectStore(store);
      for (String indexName in store.indexNames) {
        Index index = store.index(indexName);
        IdbIndexMeta indexMeta = new IdbIndexMeta.fromIndex(index);
        storeMeta.putIndex(indexMeta);
      }
      schemaMeta.stores.add(storeMeta);
    }
    await txn.completed;
  }

  _onUpgradeNeeded(VersionChangeEvent event) {
    Database db = event.database;
    for (IdbObjectStoreMeta storeMeta in schemaMeta.stores) {
      ObjectStore store = db.createObjectStore(storeMeta.name,
          keyPath: storeMeta.keyPath, autoIncrement: storeMeta.autoIncrement);
      for (IdbIndexMeta indexMeta in storeMeta.indecies) {
        store.createIndex(indexMeta.name, indexMeta.keyPath,
            unique: indexMeta.unique, multiEntry: indexMeta.multiEntry);
      }
    }
  }

  // Open and copy scheme
  Database dstDatabase = await dstFactory.open(dstDbName,
      version: version, onUpgradeNeeded: _onUpgradeNeeded);
  return dstDatabase;
}

class _Record {
  var value;
  var key;
}

Future copyStore(Database srcDatabase, String srcStoreName,
    Database dstDatabase, String dstStoreName) async {
  // Copy all in Memory first
  List<_Record> records = [];

  Transaction srcTransaction =
      srcDatabase.transaction(srcStoreName, idbModeReadOnly);
  ObjectStore store = srcTransaction.objectStore(srcStoreName);
  store.openCursor(autoAdvance: true).listen((CursorWithValue cwv) {
    records.add(new _Record()
      ..key = cwv.key
      ..value = cwv.value);
  });
  await srcTransaction.completed;

  Transaction dstTransaction =
      dstDatabase.transaction(dstStoreName, idbModeReadWrite);
  store = dstTransaction.objectStore(dstStoreName);
  // clear the existing records
  await store.clear();
  for (_Record record in records) {
    store.put(record.value, record.key);
  }
  await dstTransaction.completed;
}

Future<Database> copyDatabase(
    Database srcDatabase, IdbFactory dstFactory, String dstDbName) async {
  Database dstDatabase = await copySchema(srcDatabase, dstFactory, dstDbName);
  for (String storeName in srcDatabase.objectStoreNames) {
    await copyStore(srcDatabase, storeName, dstDatabase, storeName);
  }
  return dstDatabase;
}
