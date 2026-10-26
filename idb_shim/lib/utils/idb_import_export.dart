library;

import 'dart:async';

import 'package:sembast/sembast_memory.dart' as sembast;
import 'package:sembast/utils/sembast_import_export.dart' as sembast;

import '../idb_client_sembast.dart';
import '../src/native_value_export.dart';
import 'idb_utils.dart';
export 'package:idb_shim/idb_shim.dart';
export 'package:idb_shim/src/native_value_export.dart'
    show
        IdbExportNativeValue,
        IdbExportNativeValueContext,
        IdbExportNativeValueEncoder;

var _exportId = 0;
String get _tempExportPath => 'sembast://tmp/idb_shim/${++_exportId}';

/// Compat
@Deprecated('Use idbExportDatabase')
Future<Map<String, Object?>> sdbExportDatabase(Database db) async {
  return idbExportDatabase(db);
}

/// export a database in a sdb export format
///
/// A native value ([IdbNativeValue]) cannot be exported as is: the export
/// throws an `ArgumentError` unless [nativeValueEncoder] converts or drops
/// it.
Future<Map<String, Object?>> idbExportDatabase(
  Database db, {
  IdbExportNativeValueEncoder? nativeValueEncoder,
}) => _idbExportDatabase(db, nativeValueEncoder, sembast.exportDatabase);

/// Export through sembast, copying [db] to a memory database when it is not
/// a sembast one or when its native values must be converted.
Future<T> _idbExportDatabase<T>(
  Database db,
  IdbExportNativeValueEncoder? nativeValueEncoder,
  Future<T> Function(sembast.Database db) export,
) async {
  var srcIdbFactory = db.factory;

  // if already a sembast database use it, a sembast database with a storage
  // has no native value.
  if (srcIdbFactory is IdbFactorySembast &&
      (nativeValueEncoder == null || srcIdbFactory.persistent)) {
    return export(srcIdbFactory.getSdbDatabase(db)!);
  }
  // otherwise copy to a memory one
  var tmpPath = _tempExportPath;
  var tmpDb = await copyDatabase(db, idbFactoryMemory, tmpPath);
  try {
    if (nativeValueEncoder != null) {
      await _encodeNativeValues(tmpDb, nativeValueEncoder);
    }
    return await export(
      (idbFactoryMemory as IdbFactorySembast).getSdbDatabase(tmpDb)!,
    );
  } finally {
    tmpDb.close();
    await idbFactoryMemory.deleteDatabase(tmpPath);
  }
}

/// Converts the native values of [db] (a memory copy) in place.
Future<void> _encodeNativeValues(
  Database db,
  IdbExportNativeValueEncoder nativeValueEncoder,
) async {
  for (var storeName in db.objectStoreNames) {
    var records = <(Object, Object)>[];
    var txn = db.transaction(storeName, idbModeReadOnly);
    await txn.objectStore(storeName).openCursor(autoAdvance: true).listen((
      cwv,
    ) {
      var value = cwv.value;
      if (IdbNativeValueExportConverter.hasNativeValue(value)) {
        records.add((cwv.primaryKey, value));
      }
    }).asFuture<void>();
    await txn.completed;
    if (records.isEmpty) {
      continue;
    }
    // Converted outside of any transaction, the encoder can be asynchronous.
    var converted = <(Object, Object?)>[];
    for (var (key, value) in records) {
      converted.add((
        key,
        await IdbNativeValueExportConverter(
          storeName,
          key,
          nativeValueEncoder,
        ).convertRecordValue(value),
      ));
    }
    txn = db.transaction(storeName, idbModeReadWrite);
    var store = txn.objectStore(storeName);
    for (var (key, value) in converted) {
      if (value == null) {
        await store.delete(key);
      } else if (store.keyPath != null) {
        await store.put(value);
      } else {
        await store.put(value, key);
      }
    }
    await txn.completed;
  }
}

/// Compat
@Deprecated('Use idbImportDatabase')
Future<Database> sdbImportDatabase(
  Object data,
  IdbFactory dstFactory,
  String dstDbName,
) {
  return idbImportDatabase(data, dstFactory, dstDbName);
}

/// Copy a database export (lines or map sembast export) to another
///
/// return the opened database
Future<Database> idbImportDatabase(
  Object data,
  IdbFactory dstFactory,
  String dstDbName,
) async {
  // if it is a sembast factory use it!
  // if (false) {
  if (dstFactory is IdbFactorySembast) {
    final sdbDb = await sembast.importDatabaseAny(
      data,
      dstFactory.sdbFactory,
      dstFactory.getDbPath(dstDbName),
    );
    return dstFactory.openFromSdbDatabase(sdbDb);
  } else {
    // import to a memory one
    var tmpPath = _tempExportPath;
    final sdbDb = await sembast.importDatabaseAny(
      data,
      sembast.databaseFactoryMemory,
      tmpPath,
    );
    final tmpDb = await (idbFactoryMemory as IdbFactorySembast)
        .openFromSdbDatabase(sdbDb);
    try {
      return await copyDatabase(tmpDb, dstFactory, dstDbName);
    } finally {
      tmpDb.close();
      await idbFactoryMemory.deleteDatabase(tmpPath);
    }
  }
}

/// export a database in a sdb export format
///
/// See [idbExportDatabase] for [nativeValueEncoder].
Future<List<Object>> idbExportDatabaseLines(
  Database db, {
  IdbExportNativeValueEncoder? nativeValueEncoder,
}) => _idbExportDatabase(db, nativeValueEncoder, sembast.exportDatabaseLines);
