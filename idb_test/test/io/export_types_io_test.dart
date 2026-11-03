@TestOn('vm')
library;

import 'dart:io';

import 'package:idb_shim/sdb.dart';
// ignore: implementation_imports
import 'package:idb_shim/src/sdb/sdb_database_impl.dart' show SdbDatabaseImpl;
// ignore: implementation_imports
import 'package:idb_shim/src/sdb/sdb_import_export.dart'
    show sdbExportDatabaseLinesGeneric, sdbImportDatabaseGeneric;
import 'package:idb_shim/utils/idb_import_export.dart' as idb;
import 'package:idb_shim/utils/sdb_import_export.dart';
import 'package:idb_test/src/export_types_example.dart';
import 'package:path/path.dart';
import 'package:sembast/utils/sembast_import_export.dart'
    show decodeImportAny, exportLinesToJsonlString;
import 'package:test/test.dart';

/// The custom types example (SdbTimestamp, SdbBlob next to DateTime,
/// Uint8List, see `lib/src/export_types_example.dart`) in `test/data`:
/// - sdb_types_export1.jsonl: the current sdb export (`sdb_export` marker);
/// - sdb_types_legacy_export1.jsonl: the legacy export (the idb export, the
///   sdb export before the marker), it must never change;
/// - sdb_types_dollar_export1.jsonl: the current `$` sdb export;
/// - idb_sembast_io_types_db1.jsonl: the idb on sembast io database file
///   (unchanged format).
String _dataPath(String name) => join('test', 'data', name);

/// The content of a test data file with \n line endings (a Windows checkout
/// can turn them into \r\n).
Future<String> _readData(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

const _dollar = SdbExportOptions(typeEncoding: SdbExportTypeEncoding.dollar);

/// The io factory of the tests (a sandbox).
final _ioFactory = sdbFactoryIo.sandbox(
  path: join('.local', 'test', 'export_types_io'),
);

void main() {
  late String typesExport1;
  late String typesLegacyExport1;
  late String typesDollarExport1;
  late String typesIoDb1;
  setUpAll(() async {
    typesExport1 = await _readData(_dataPath('sdb_types_export1.jsonl'));
    typesLegacyExport1 = await _readData(
      _dataPath('sdb_types_legacy_export1.jsonl'),
    );
    typesDollarExport1 = await _readData(
      _dataPath('sdb_types_dollar_export1.jsonl'),
    );
    typesIoDb1 = await _readData(_dataPath('idb_sembast_io_types_db1.jsonl'));
  });

  Future<String> sdbExportJsonl(
    SdbDatabase db, {
    SdbExportOptions? options,
  }) async => exportLinesToJsonlString(
    await sdbExportDatabaseLines(db, options: options),
  );

  group('export_types_io', () {
    test('formats', () {
      expect(
        typesLegacyExport1.split('\n').first,
        '{"sembast_export":1,"version":1}',
      );
      // Only the header differs between the legacy and the current export.
      expect(
        typesExport1.split('\n').skip(1),
        typesLegacyExport1.split('\n').skip(1),
      );
      // The sdb custom types are stored as $Timestamp/$Blob, the native
      // ones are exported as @Timestamp/@Blob.
      expect(typesLegacyExport1, contains('{"\$Timestamp":'));
      expect(typesLegacyExport1, contains('{"@Timestamp":'));
      // In the $ export, the native ones are exported as $Timestamp/$Blob
      // and the stored $Timestamp/$Blob are escaped.
      expect(typesDollarExport1, contains(r'"dateTime":{"$Timestamp":'));
      expect(typesDollarExport1, contains(r'"timestamp":{"$":{"$Timestamp":'));
    });

    test('export', () async {
      var db = await sdbExportTypesCreateExample1(
        newSdbFactoryMemory(),
        'types.db',
      );
      try {
        await sdbExportTypesCheckExample1(db);
        expect(await sdbExportJsonl(db), typesExport1);
        expect(await sdbExportJsonl(db, options: _dollar), typesDollarExport1);
        expect(
          exportLinesToJsonlString(await sdbExportDatabaseLinesGeneric(db)),
          typesExport1,
        );
        expect(
          exportLinesToJsonlString(
            await idb.idbExportDatabaseLines(
              (db as SdbDatabaseImpl).idbDatabase,
            ),
          ),
          typesLegacyExport1,
        );
      } finally {
        await db.close();
      }
    });

    test('import, re-export', () async {
      for (var export in [
        typesExport1,
        typesLegacyExport1,
        typesDollarExport1,
      ]) {
        for (var (name, import) in [
          (
            'memory',
            () => sdbImportDatabase(export, newSdbFactoryMemory(), 'i.db'),
          ),
          ('io', () => sdbImportDatabase(export, _ioFactory, 'i.db')),
          (
            'generic',
            () => sdbImportDatabaseGeneric(
              decodeImportAny(export),
              newSdbFactoryMemory(),
              'i.db',
            ),
          ),
        ]) {
          var db = await import();
          try {
            await sdbExportTypesCheckExample1(db);
            expect(await sdbExportJsonl(db), typesExport1, reason: name);
            expect(
              await sdbExportJsonl(db, options: _dollar),
              typesDollarExport1,
              reason: name,
            );
          } finally {
            await db.close();
          }
        }
      }
    });

    test('io database file', () async {
      // The import writes the example file.
      var db = await sdbImportDatabase(
        typesLegacyExport1,
        _ioFactory,
        'types.db',
      );
      await db.close();
      var path = await _ioFactory.getDatabaseFullPath('types.db');
      expect(await File(path).readAsString(), typesIoDb1);

      // Opened (written, a database file can be rewritten when opened).
      await File(path).writeAsString(typesIoDb1);
      db = await _ioFactory.openDatabase('types.db');
      try {
        await sdbExportTypesCheckExample1(db);
        expect(await sdbExportJsonl(db), typesExport1);
      } finally {
        await db.close();
      }
      expect(await File(path).readAsString(), typesIoDb1);
    });
  });
}
