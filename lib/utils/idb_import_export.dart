library idb_shim.utils;

import '../idb_client.dart';
import '../idb_client_sembast.dart';
import '../idb_client_memory.dart';
import 'package:sembast/sembast_memory.dart' as sdb;
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:sembast/sembast.dart' as sdb;
import 'idb_utils.dart';
import 'dart:async';

///
/// export a database in a sdb export format
///
Future<Map> sdbExportDatabase(Database db) async {
  var srcIdbFactory = db.factory;

  sdb.Database sdbDatabase;

  // if already a sembast database use it
  if (srcIdbFactory is IdbSembastFactory) {
    sdbDatabase = srcIdbFactory.getSdbDatabase(db);
    return exportDatabase(sdbDatabase);
  } else {
    // otherwise copy to a memory one
    db = await copyDatabase(db, idbMemoryFactory, null);
    sdbDatabase = srcIdbFactory.getSdbDatabase(db);
    Map export = await exportDatabase(sdbDatabase);
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
  if (dstFactory is IdbSembastFactory) {
    sdb.Database sdbDb =
        await importDatabase(data, dstFactory.sdbFactory, dstDbName);
    return dstFactory.openFromSdbDatabase(sdbDb);
  } else {
    // import to a memory one
    sdb.Database sdbDb =
        await importDatabase(data, sdb.memoryDatabaseFactory, null);
    Database tmpDb = await (idbMemoryFactory as IdbSembastFactory)
        .openFromSdbDatabase(sdbDb);
    Database db = await copyDatabase(tmpDb, dstFactory, dstDbName);
    tmpDb.close();
    return db;
  }
}
