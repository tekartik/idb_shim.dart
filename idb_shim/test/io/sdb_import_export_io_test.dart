@TestOn('vm')
library;

import 'dart:io';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_import_export.dart'
    show sdbExportDatabaseLinesGeneric, sdbImportDatabaseGeneric;
import 'package:idb_shim/utils/sdb_import_export.dart';
import 'package:path/path.dart';
import 'package:sembast/utils/sembast_import_export.dart'
    show decodeImportAny, exportLinesToJsonlString;
import 'package:test/test.dart';

import 'sdb_export_example1.dart';

/// The exhaustive example, the same database (2 stores, 5 records, every
/// type):
/// - sdb_export1.jsonl: its sdb export;
/// - idb_sembast_io_db1.jsonl: its idb on sembast io database file.
///
/// The other formats (legacy export, `$` exports, the `$`/`@` combinations)
/// are tested on every factory by idb_test (`sdb_export_format_test.dart`).
final _sdbExport1Path = join('test', 'data', 'sdb_export1.jsonl');
final _idbSembastIoDb1Path = join('test', 'data', 'idb_sembast_io_db1.jsonl');

/// The io factory of the tests (a sandbox).
final _ioFactory = sdbFactoryIo.sandbox(
  path: join('.local', 'test', 'sdb_import_export_io'),
);

/// The content of a test data file with \n line endings (a Windows checkout
/// can turn them into \r\n).
Future<String> _readData(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

/// The jsonl export of [db].
Future<String> _exportJsonl(SdbDatabase db) async =>
    exportLinesToJsonlString(await sdbExportDatabaseLines(db));

void main() {
  late String sdbExport1;
  late String idbSembastIoDb1;
  setUpAll(() async {
    sdbExport1 = await _readData(_sdbExport1Path);
    idbSembastIoDb1 = await _readData(_idbSembastIoDb1Path);
  });

  group('sdb_import_export_io', () {
    test('export', () async {
      var db = await sdbCreateExample1(newSdbFactoryMemory(), 'export1.db');
      try {
        expect(await _exportJsonl(db), sdbExport1);
        // The generic export (non idb sdb implementations) is the same.
        expect(
          exportLinesToJsonlString(await sdbExportDatabaseLinesGeneric(db)),
          sdbExport1,
        );
      } finally {
        await db.close();
      }
    });

    test('import, re-export', () async {
      for (var (name, import) in [
        (
          'memory',
          () => sdbImportDatabase(sdbExport1, newSdbFactoryMemory(), 'i.db'),
        ),
        // A sandbox: the database is imported in it.
        ('io', () => sdbImportDatabase(sdbExport1, _ioFactory, 'i.db')),
        (
          'generic',
          () => sdbImportDatabaseGeneric(
            decodeImportAny(sdbExport1),
            newSdbFactoryMemory(),
            'i.db',
          ),
        ),
      ]) {
        var db = await import();
        try {
          await sdbCheckExample1(db);
          expect(await _exportJsonl(db), sdbExport1, reason: name);
        } finally {
          await db.close();
        }
      }
    });

    test('io database file', () async {
      // The import writes the example file.
      var db = await sdbImportDatabase(sdbExport1, _ioFactory, 'db1.db');
      await db.close();
      var path = await _ioFactory.getDatabaseFullPath('db1.db');
      expect(await File(path).readAsString(), idbSembastIoDb1);

      // Opened (written, a database file can be rewritten when opened).
      await File(path).writeAsString(idbSembastIoDb1);
      db = await _ioFactory.openDatabase('db1.db');
      try {
        await sdbCheckExample1(db, checkAutoIncrement: false);
        expect(await _exportJsonl(db), sdbExport1);
      } finally {
        await db.close();
      }
      expect(await File(path).readAsString(), idbSembastIoDb1);
    });
  });
}
