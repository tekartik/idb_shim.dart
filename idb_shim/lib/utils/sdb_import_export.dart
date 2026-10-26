library;

import 'dart:async';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_database_impl.dart';
import 'package:idb_shim/src/sdb/sdb_factory_impl.dart';
import 'package:idb_shim/src/sdb/sdb_import_export.dart';

import 'idb_import_export.dart' as idb;
import 'idb_import_export.dart';

export 'package:idb_shim/idb_shim.dart';
export 'package:idb_shim/src/sdb/sdb_import_export.dart'
    show
        SdbExportNativeValue,
        SdbExportNativeValueContext,
        SdbExportNativeValueEncoder;

/// export a database in a sembast db export format
///
/// A native value (`SdbNativeValue`) cannot be exported as is: the export
/// throws an `ArgumentError` unless [nativeValueEncoder] converts or drops
/// it.
Future<List<Object>> sdbExportDatabaseLines(
  SdbDatabase db, {
  SdbExportNativeValueEncoder? nativeValueEncoder,
}) async {
  if (db is SdbDatabaseImpl) {
    // idb based, export the underlying database.
    return idb.idbExportDatabaseLines(
      db.idbDatabase,
      nativeValueEncoder: nativeValueEncoder,
    );
  }
  return sdbExportDatabaseLinesGeneric(
    db,
    nativeValueEncoder: nativeValueEncoder,
  );
}

/// Import a database from sdb export lines
Future<SdbDatabase> sdbImportDatabase(
  Object data,
  SdbFactory dstFactory,
  String dstDbName, {
  SdbCodec? codec,
}) async {
  if (dstFactory is SdbFactoryIdb) {
    // idb based, import the underlying database.
    var idbDatabase = await idbImportDatabase(
      data,
      dstFactory.idbFactory,
      dstDbName,
    );
    return SdbDatabaseImpl.idbDatabase(dstFactory, idbDatabase, codec: codec);
  }
  return sdbImportDatabaseGeneric(data, dstFactory, dstDbName, codec: codec);
}
