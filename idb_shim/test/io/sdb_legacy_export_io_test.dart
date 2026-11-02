@TestOn('vm')
library;

import 'dart:io';

import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_database_impl.dart';
import 'package:idb_shim/utils/idb_import_export.dart';
import 'package:idb_shim/utils/sdb_import_export.dart' as sdb;
import 'package:path/path.dart';
import 'package:sembast/utils/sembast_import_export.dart'
    show exportLinesToJsonlString;
import 'package:test/test.dart';

import 'sdb_export_example1.dart';

/// The legacy formats of the exhaustive example (2 stores, 5 records, every
/// type), as written before the export options and markers. They must never
/// change, the test only uses the api that existed then:
/// - sdb_legacy_export1.jsonl: the idb export, and the sdb export without
///   its `sdb_export` header key;
/// - idb_sembast_io_db1.jsonl: the idb on sembast io database file.
final _legacyExport1Path = join('test', 'data', 'sdb_legacy_export1.jsonl');
final _idbSembastIoDb1Path = join('test', 'data', 'idb_sembast_io_db1.jsonl');

/// Root of the io files written by the tests.
final _ioTestPath = join('.local', 'test', 'sdb_legacy_export_io');

/// [lines] without the `sdb_export` header key (added by the sdb export).
List<Object> _withoutSdbExportKey(List<Object> lines) => [
  Map<String, Object?>.from(lines.first as Map)..remove('sdb_export'),
  ...lines.skip(1),
];

Future<String> _idbExportJsonl(Database db) async =>
    exportLinesToJsonlString(await idbExportDatabaseLines(db));

void main() {
  late String legacyExport1;
  late String idbSembastIoDb1;
  setUpAll(() async {
    legacyExport1 = await File(_legacyExport1Path).readAsString();
    idbSembastIoDb1 = await File(_idbSembastIoDb1Path).readAsString();
  });

  group('sdb_legacy_export_io', () {
    test('header', () {
      expect(
        legacyExport1.split('\n').first,
        '{"sembast_export":1,"version":1}',
      );
    });

    test('export', () async {
      var db = await sdbCreateExample1(newSdbFactoryMemory(), 'legacy1.db');
      try {
        expect(
          await _idbExportJsonl((db as SdbDatabaseImpl).idbDatabase),
          legacyExport1,
        );
        expect(
          exportLinesToJsonlString(
            _withoutSdbExportKey(await sdb.sdbExportDatabaseLines(db)),
          ),
          legacyExport1,
        );
      } finally {
        await db.close();
      }
    });

    test('import, re-export', () async {
      var db = await sdb.sdbImportDatabase(
        legacyExport1,
        newSdbFactoryMemory(),
        'imported.db',
      );
      try {
        await sdbCheckExample1(db);
        expect(
          await _idbExportJsonl((db as SdbDatabaseImpl).idbDatabase),
          legacyExport1,
        );
      } finally {
        await db.close();
      }
      var idbDb = await idbImportDatabase(
        legacyExport1,
        newIdbFactoryMemory(),
        'imported.db',
      );
      try {
        expect(await _idbExportJsonl(idbDb), legacyExport1);
      } finally {
        idbDb.close();
      }
    });

    test('io database file', () async {
      // The import writes the example file.
      var path = join(_ioTestPath, 'db1.db');
      var idbDb = await idbImportDatabase(
        legacyExport1,
        idbFactorySembastIo,
        path,
      );
      idbDb.close();
      expect(await File(path).readAsString(), idbSembastIoDb1);

      // Opened (copied, a database file can be rewritten when opened).
      await File(_idbSembastIoDb1Path).copy(path);
      var db = await sdbFactoryIo.openDatabase(path);
      try {
        await sdbCheckExample1(db, checkAutoIncrement: false);
        expect(
          await _idbExportJsonl((db as SdbDatabaseImpl).idbDatabase),
          legacyExport1,
        );
      } finally {
        await db.close();
      }
      expect(await File(path).readAsString(), idbSembastIoDb1);
    });
  });
}
