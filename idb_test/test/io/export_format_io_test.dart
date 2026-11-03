@TestOn('vm')
library;

import 'dart:io';

import 'package:idb_shim/sdb.dart';
// ignore: implementation_imports
import 'package:idb_shim/src/sdb/sdb_database_impl.dart' show SdbDatabaseImpl;
import 'package:idb_shim/utils/sdb_import_export.dart';
import 'package:idb_test/sdb_export_format_test.dart';
import 'package:idb_test/src/export_format_data.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

/// The example files of `test/data`, the same database:
/// - legacy_export1.jsonl: the legacy export (`@Timestamp`, `@Blob`), it must
///   never change.
/// - sdb_export1.jsonl: the sdb export (`sdb_export` marker).
/// - idb_dollar_export1.jsonl, sdb_dollar_export1.jsonl: the `$` exports.
/// - idb_sembast_io_db1.jsonl: the idb on sembast io database file.
String _dataPath(String name) => join('test', 'data', name);

/// The content of a test data file with \n line endings (a Windows checkout
/// can turn them into \r\n).
Future<String> _readData(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

/// Root of the io files written by the tests.
final _ioTestPath = join('.local', 'test', 'export_format_io');

void main() {
  group('export_format_io', () {
    test('data files are the embedded examples', () async {
      for (var (name, content) in [
        ('legacy_export1.jsonl', legacyExport1Jsonl),
        ('sdb_export1.jsonl', sdbExport1Jsonl),
        ('idb_dollar_export1.jsonl', idbDollarExport1Jsonl),
        ('sdb_dollar_export1.jsonl', sdbDollarExport1Jsonl),
      ]) {
        expect(
          await _readData(_dataPath(name)),
          content,
          reason: '$name differs from lib/src/export_format_data.dart',
        );
      }
    });

    group('idb sembast io db file', () {
      var factory = sdbFactoryIo.sandbox(path: _ioTestPath);
      late String idbSembastIoDb1;
      setUpAll(() async {
        idbSembastIoDb1 = await _readData(
          _dataPath('idb_sembast_io_db1.jsonl'),
        );
      });

      test('import writes the example file', () async {
        for (var export in [legacyExport1Jsonl, sdbExport1Jsonl]) {
          var db = await sdbImportDatabase(export, factory, 'db1.db');
          await db.close();
          expect(
            await File(
              await factory.getDatabaseFullPath('db1.db'),
            ).readAsString(),
            idbSembastIoDb1,
          );
        }
      });

      test('open, export', () async {
        // Written, a database file can be rewritten when opened.
        var path = await factory.getDatabaseFullPath('db1_copy.db');
        await File(path).parent.create(recursive: true);
        await File(path).writeAsString(idbSembastIoDb1);
        var db = await factory.openDatabase('db1_copy.db');
        try {
          await sdbExportFormatCheckExample1(db, checkAutoIncrement: false);
          expect(await sdbExportFormatSdbExportJsonl(db), sdbExport1Jsonl);
          expect(
            await sdbExportFormatSdbExportJsonl(
              db,
              typeEncoding: SdbExportTypeEncoding.dollar,
            ),
            sdbDollarExport1Jsonl,
          );
          expect(
            await sdbExportFormatIdbExportJsonl(
              (db as SdbDatabaseImpl).idbDatabase,
            ),
            legacyExport1Jsonl,
          );
        } finally {
          await db.close();
        }
        expect(await File(path).readAsString(), idbSembastIoDb1);
      });
    });
  });
}
