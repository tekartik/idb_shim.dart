library idb_shim.utils.idb_utils;

import 'dart:async';

import 'package:idb_shim/src/utils/core_imports.dart';

import '../idb_client.dart';
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

  _SchemaMeta schemaMeta = _SchemaMeta();
  // Get schema
  List<String> storeNames = List.from(srcDatabase.objectStoreNames);
  if (storeNames.isNotEmpty) {
    Transaction txn = srcDatabase.transactionList(storeNames, idbModeReadOnly);
    for (String storeName in storeNames) {
      ObjectStore store = txn.objectStore(storeName);
      IdbObjectStoreMeta storeMeta = IdbObjectStoreMeta.fromObjectStore(store);
      for (String indexName in store.indexNames) {
        Index index = store.index(indexName);
        IdbIndexMeta indexMeta = IdbIndexMeta.fromIndex(index);
        storeMeta.putIndex(indexMeta);
      }
      schemaMeta.stores.add(storeMeta);
    }
    await txn.completed;
  }

  void _onUpgradeNeeded(VersionChangeEvent event) {
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
    records.add(_Record()
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
    // ignore: unawaited_futures
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

class CursorRow extends KeyCursorRow {
  final dynamic value;

  CursorRow(dynamic key, dynamic primaryKey, this.value)
      : super(key, primaryKey);

  @override
  String toString() {
    return '$value';
  }
}

class KeyCursorRow {
  final dynamic key;
  final dynamic primaryKey;

  @override
  String toString() {
    return '$key $primaryKey';
  }

  KeyCursorRow(this.key, this.primaryKey);
}

/// Convert an openCursor stream to a list
Future<List<CursorRow>> cursorToList(Stream<CursorWithValue> stream) {
  var completer = Completer<List<CursorRow>>.sync();
  List<CursorRow> list = [];
  stream.listen((CursorWithValue cwv) {
    list.add(CursorRow(cwv.key, cwv.primaryKey, cwv.value));
  }).onDone(() {
    completer.complete(list);
  });
  return completer.future;
}

/// Convert an openKeyCursor stream to a list
Future<List<KeyCursorRow>> keyCursorToList(Stream<Cursor> stream) {
  var completer = Completer<List<KeyCursorRow>>.sync();
  List<KeyCursorRow> list = [];
  stream.listen((Cursor cursor) {
    list.add(KeyCursorRow(cursor.key, cursor.primaryKey));
  }).onDone(() {
    completer.complete(list);
  });
  return completer.future;
}
