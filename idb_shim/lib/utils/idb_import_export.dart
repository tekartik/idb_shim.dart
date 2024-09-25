library idb_shim.utils.idb_import_export;

import 'dart:async';

import 'package:sembast/sembast.dart' as sdb;
import 'package:sembast/sembast_memory.dart' as sdb;
import 'package:sembast/utils/sembast_import_export.dart';

import '../idb_client_sembast.dart';
import 'idb_utils.dart';
export 'package:idb_shim/idb_shim.dart';

var _exportId = 0;
String get _tempExportPath => 'sembast://tmp/idb_shim/${++_exportId}';

///
/// export a database in a sdb export format
///
Future<Map<String, Object?>> sdbExportDatabase(Database db) async {
  var srcIdbFactory = db.factory;

  sdb.Database? sdbDatabase;

  // if already a sembast database use it
  // if (false) {
  if (srcIdbFactory is IdbFactorySembast) {
    sdbDatabase = srcIdbFactory.getSdbDatabase(db);
    return exportDatabase(sdbDatabase!);
  } else {
    // otherwise copy to a memory one
    db = await copyDatabase(db, idbFactoryMemory, _tempExportPath);
    sdbDatabase = (idbFactoryMemory as IdbFactorySembast).getSdbDatabase(db);
    var export = await exportDatabase(sdbDatabase!);
    db.close();
    return export;
  }
}

///
/// Copy a database export (lines or map sembast export) to another
///
/// return the opened database
///
Future<Database> sdbImportDatabase(
    Object data, IdbFactory dstFactory, String dstDbName) async {
  // if it is a sembast factory use it!
  // if (false) {
  if (dstFactory is IdbFactorySembast) {
    final sdbDb = await importDatabaseAny(
        data, dstFactory.sdbFactory, dstFactory.getDbPath(dstDbName));
    return dstFactory.openFromSdbDatabase(sdbDb);
  } else {
    // import to a memory one
    final sdbDb = await importDatabaseAny(
        data, sdb.databaseFactoryMemory, _tempExportPath);
    final tmpDb = await (idbFactoryMemory as IdbFactorySembast)
        .openFromSdbDatabase(sdbDb);
    final db = await copyDatabase(tmpDb, dstFactory, dstDbName);
    tmpDb.close();
    return db;
  }
}

///
/// export a database in a sdb export format
///
Future<List<Object>> sdbExportDatabaseLines(Database db) async {
  var srcIdbFactory = db.factory;

  sdb.Database? sdbDatabase;

  // if already a sembast database use it
  // if (false) {
  if (srcIdbFactory is IdbFactorySembast) {
    sdbDatabase = srcIdbFactory.getSdbDatabase(db);
    return exportDatabaseLines(sdbDatabase!);
  } else {
    // otherwise copy to a memory one
    db = await copyDatabase(db, idbFactoryMemory, _tempExportPath);
    sdbDatabase = (idbFactoryMemory as IdbFactorySembast).getSdbDatabase(db);
    var export = await exportDatabaseLines(sdbDatabase!);
    db.close();
    return export;
  }
}
