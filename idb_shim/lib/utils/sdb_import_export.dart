library;

import 'dart:async';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_database_impl.dart';
import 'package:idb_shim/src/sdb/sdb_factory_impl.dart';
import 'package:idb_shim/src/sdb/sdb_import_export.dart';
import 'package:sembast/utils/sembast_import_export.dart' show decodeImportAny;

import 'idb_import_export.dart' as idb;
import 'idb_import_export.dart';

export 'package:idb_shim/idb_shim.dart';
export 'package:idb_shim/src/sdb/sdb_import_export.dart'
    show
        SdbExportNativeValue,
        SdbExportNativeValueContext,
        SdbExportNativeValueEncoder,
        SdbExportOptions,
        SdbExportTypeEncoding,
        SdbImportOptions;

/// export a database in a sembast db export format
///
/// The header has an `sdb_export` marker (`{'sembast_export': 1,
/// 'version': 1, 'sdb_export': 1}`): still a sembast export, it tells the
/// export can be imported by sdb and idb ([sdbImportDatabase],
/// `idbImportDatabase`).
///
/// A native value (`SdbNativeValue`) cannot be exported as is: the export
/// throws an `ArgumentError` unless [nativeValueEncoder] (or the one of
/// [options], that overrides it) converts or drops it.
///
/// [options] can give the encoding of the custom types (DateTime,
/// Uint8List): the legacy `@` one by default (`{"@Timestamp": ...}`,
/// `{"@Blob": ...}`), or `$` (`{"$Timestamp": ...}`, `{"$Blob": ...}`, the
/// header then has `"type_prefix": "$"`).
///
/// [client] is a database or a transaction. A transaction exports its stores
/// in it, its changes included: writing and exporting can happen in the same
/// transaction. On the web, an asynchronous [nativeValueEncoder] can let the
/// transaction complete before the export ends.
Future<List<Object>> sdbExportDatabaseLines(
  SdbClient client, {
  SdbExportNativeValueEncoder? nativeValueEncoder,
  SdbExportOptions? options,
}) async {
  if (client is SdbDatabaseImpl) {
    // idb based, export the underlying database.
    return sdbExportLinesFromIdbExportLines(
      await idb.idbExportDatabaseLines(
        client.idbDatabase,
        nativeValueEncoder: nativeValueEncoder,
        options: options,
      ),
    );
  }
  // Any sdb database and the transactions (read in them).
  return sdbExportDatabaseLinesGeneric(
    client,
    nativeValueEncoder: nativeValueEncoder,
    options: options,
  );
}

/// Import a database from sdb export lines
///
/// [data] is a sembast export (lines, map or their json/jsonl string), with
/// or without the `sdb_export` marker (idb exports and older sdb ones have
/// none). A newer sdb export throws a `FormatException`.
///
/// The custom types are decoded in the encoding given by the export header
/// (`type_prefix`), the legacy `@` one without it. [options] can restrict the
/// accepted encodings (all by default), another one throws a
/// `FormatException`.
Future<SdbDatabase> sdbImportDatabase(
  Object data,
  SdbFactory dstFactory,
  String dstDbName, {
  SdbCodec? codec,
  SdbImportOptions? options,
}) async {
  data = decodeImportAny(data);
  sdbCheckExportHeader(data);
  if (dstFactory is SdbFactoryIdb) {
    // idb based, import the underlying database (the idb factory of a
    // sandbox is an idb sandbox, mapping the name).
    var idbDatabase = await idbImportDatabase(
      data,
      dstFactory.idbFactory,
      dstDbName,
      options: options,
    );
    return SdbDatabaseImpl.idbDatabase(dstFactory, idbDatabase, codec: codec);
  }
  return sdbImportDatabaseGeneric(
    data,
    dstFactory,
    dstDbName,
    codec: codec,
    options: options,
  );
}
