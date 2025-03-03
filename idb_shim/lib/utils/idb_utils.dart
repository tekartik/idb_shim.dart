library;

import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:idb_shim/src/utils/env_utils.dart';
import 'package:idb_shim/src/utils/idb_utils.dart';

import 'idb_cursor_utils.dart';

export 'package:idb_shim/idb_shim.dart';

export 'idb_cursor_utils.dart' show CursorRow, KeyCursorRow;

class _SchemaMeta {
  List<IdbObjectStoreMeta> stores = [];
}

///
/// Copy a database to another
/// return the opened database
///
Future<Database> copySchema(
  Database srcDatabase,
  IdbFactory dstFactory,
  String dstDbName,
) async {
  // Delete the existing
  await dstFactory.deleteDatabase(dstDbName);
  final version = srcDatabase.version;

  final schemaMeta = _SchemaMeta();
  // Get schema
  final storeNames = List<String>.from(srcDatabase.objectStoreNames);
  if (storeNames.isNotEmpty) {
    final txn = srcDatabase.transactionList(storeNames, idbModeReadOnly);
    for (final storeName in storeNames) {
      final store = txn.objectStore(storeName);
      final storeMeta = IdbObjectStoreMeta.fromObjectStore(store);
      for (final indexName in store.indexNames) {
        final index = store.index(indexName);
        final indexMeta = IdbIndexMeta.fromIndex(index);
        storeMeta.putIndex(indexMeta);
      }
      schemaMeta.stores.add(storeMeta);
    }
    await txn.completed;
  }

  void openOnUpgradeNeeded(VersionChangeEvent event) {
    final db = event.database;
    for (final storeMeta in schemaMeta.stores) {
      final store = db.createObjectStore(
        storeMeta.name,
        keyPath: storeMeta.keyPath,
        autoIncrement: storeMeta.autoIncrement,
      );
      for (final indexMeta in storeMeta.indecies) {
        var keyPath = indexMeta.keyPath;

        store.createIndex(
          indexMeta.name!,
          keyPath,
          unique: indexMeta.unique,
          multiEntry: indexMeta.multiEntry,
        );
      }
    }
  }

  // devPrint('Open $dstDbName version $version');
  // Open and copy scheme
  final dstDatabase = await dstFactory.open(
    dstDbName,
    version: version,
    onUpgradeNeeded: openOnUpgradeNeeded,
  );
  return dstDatabase;
}

class _Record {
  late Object value;
  late Object key;

  @override
  String toString() => logTruncate('$key: $value');
}

/// Copy a store from a database to another existing one.
Future copyStore(
  Database srcDatabase,
  String srcStoreName,
  Database dstDatabase,
  String dstStoreName,
) async {
  // Copy all in Memory first
  final records = <_Record>[];

  final srcTransaction = srcDatabase.transaction(srcStoreName, idbModeReadOnly);
  var store = srcTransaction.objectStore(srcStoreName);
  store.openCursor(autoAdvance: true).listen((CursorWithValue cwv) {
    records.add(
      _Record()
        ..key = cwv.key
        ..value = cwv.value,
    );
  });
  await srcTransaction.completed;

  final dstTransaction = dstDatabase.transaction(
    dstStoreName,
    idbModeReadWrite,
  );
  store = dstTransaction.objectStore(dstStoreName);
  // clear the existing records
  await store.clear();
  try {
    for (final record in records) {
      /// If key is set don't store the key
      if (store.keyPath != null) {
        // ignore: unawaited_futures
        store.put(record.value);
      } else {
        // ignore: unawaited_futures
        store.put(record.value, record.key);
      }
    }
  } catch (e) {
    if (isDebug) {
      idbLog(e);
    }
    rethrow;
  } finally {
    await dstTransaction.completed;
  }
}

/// Copy a database content to a new database.
Future<Database> copyDatabase(
  Database srcDatabase,
  IdbFactory dstFactory,
  String dstDbName,
) async {
  final dstDatabase = await copySchema(srcDatabase, dstFactory, dstDbName);
  for (final storeName in srcDatabase.objectStoreNames) {
    await copyStore(srcDatabase, storeName, dstDatabase, storeName);
  }
  return dstDatabase;
}

/// Convert an autoAdvance openCursor stream to a list.
Future<List<T>> _autoCursorStreamToList<C extends Cursor, T>(
  Stream<C> stream,
  T? Function(C cursor) convert,
  int? offset,
  int? limit,
) {
  return streamWithOffsetAndLimit(stream, offset, limit)
      .map((cursor) => convert(cursor))
      .where((cursor) => cursor != null)
      .map((cursor) => cursor!)
      .toList();
}

/// Convert an autoAdvance openCursor stream to a list
Future<List<CursorRow>> idbCursorToList(
  Stream<CursorWithValue> stream, {
  int? offset,
  int? limit,
}) => _autoCursorStreamToList(
  stream,
  (cwv) => CursorRow(cwv.key, cwv.primaryKey, cloneValue(cwv.value)),
  offset,
  limit,
);

/// Convert an autoAdvance openCursor stream to a list
Future<List<CursorRow>> cursorToList(
  Stream<CursorWithValue> stream, [
  int? offset,
  int? limit,
  IdbCursorWithValueMatcherFunction? matcher,
]) {
  CursorRow? getRow(CursorWithValue cwv) {
    if (matcher != null) {
      if (!matcher(cwv)) {
        return null;
      }
    }
    final row = CursorRow(cwv.key, cwv.primaryKey, cloneValue(cwv.value));
    return row;
  }

  return _autoCursorStreamToList(stream, (cwv) => getRow(cwv), offset, limit);
}

/// Convert an autoAdvance openKeyCursor stream to a list
Future<List<KeyCursorRow>> keyCursorToList(
  Stream<Cursor> stream, [
  int? offset,
  int? limit,
]) => _autoCursorStreamToList(
  stream,
  (cursor) => KeyCursorRow(cursor.key, cursor.primaryKey),
  offset,
  limit,
);

/// Convert an autoAdvance openKeyCursor stream to a list of key, must be auto-advance)
Future<List<Object>> cursorToPrimaryKeyList(
  Stream<Cursor> stream, [
  int? offset,
  int? limit,
]) => _autoCursorStreamToList(
  stream,
  (cursor) => cursor.primaryKey,
  offset,
  limit,
);

/// Convert an autoAdvance openKeyCursor stream to a list (must be auto-advance)
Future<List<Object>> cursorToKeyList(
  Stream<Cursor> stream, [
  int? offset,
  int? limit,
]) => _autoCursorStreamToList(stream, (cursor) => cursor.key, offset, limit);
