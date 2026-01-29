library;

import 'dart:async';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_database_impl.dart';
import 'package:idb_shim/src/sdb/sdb_factory_impl.dart';

import 'idb_import_export.dart' as idb;
import 'idb_import_export.dart';

export 'package:idb_shim/idb_shim.dart';

///
/// export a database in a sembast db export format
///
Future<List<Object>> sdbExportDatabaseLines(SdbDatabase db) async {
  var srcIdb = db.impl.idbDatabase;
  return idb.idbExportDatabaseLines(srcIdb);
}

/// Import a database from sdb export lines
Future<SdbDatabase> sdbImportDatabase(
  Object data,
  SdbFactory dstFactory,
  String dstDbName,
) async {
  var idbFactory = dstFactory.idbFactory;
  var idbDatabase = await idbImportDatabase(data, idbFactory, dstDbName);
  return SdbDatabaseImpl.idbDatabase(dstFactory as SdbFactoryImpl, idbDatabase);
}
