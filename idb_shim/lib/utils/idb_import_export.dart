library idb_shim.utils.idb_import_export;

import 'dart:async';

import 'package:sembast/sembast.dart' as sdb;
import 'package:sembast/sembast_memory.dart' as sdb;
import 'package:sembast/utils/sembast_import_export.dart';

import '../idb_client.dart';
import '../idb_client_memory.dart';
import '../idb_client_sembast.dart';
import 'idb_utils.dart';

///
/// export a database in a sdb export format
///
Future<Map> sdbExportDatabase(Database db) async {
  var srcIdbFactory = db.factory;

  sdb.Database? sdbDatabase;

  // if already a sembast database use it
  // if (false) {
  if (srcIdbFactory is IdbFactorySembast) {
    sdbDatabase = srcIdbFactory.getSdbDatabase(db);
    return exportDatabase(sdbDatabase!);
  } else {
    // otherwise copy to a memory one
    db = await copyDatabase(db, idbFactoryMemory, null);
    sdbDatabase = (idbFactoryMemory as IdbFactorySembast).getSdbDatabase(db);
    Map export = await exportDatabase(sdbDatabase!);
    db.close();
    return export;
  }
}

///
/// Copy a database to another
/// return the opened database
///
Future<Database> sdbImportDatabase(
    Map data, IdbFactory dstFactory, String dstDbName) async {
  // if it is a sembast factory use it!
  // if (false) {
  if (dstFactory is IdbFactorySembast) {
    final sdbDb = await importDatabase(
        data, dstFactory.sdbFactory, dstFactory.getDbPath(dstDbName));
    return dstFactory.openFromSdbDatabase(sdbDb);
  } else {
    // import to a memory one
    final sdbDb = await importDatabase(data, sdb.databaseFactoryMemory, null);
    final tmpDb = await (idbFactoryMemory as IdbFactorySembast)
        .openFromSdbDatabase(sdbDb);
    final db = await copyDatabase(tmpDb, dstFactory, dstDbName);
    tmpDb.close();
    return db;
  }
}
