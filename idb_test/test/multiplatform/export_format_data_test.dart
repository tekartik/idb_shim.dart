library;

import 'package:idb_test/src/export_format_data.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:test/test.dart';

String _firstLine(String jsonl) => jsonl.split('\n').first;

/// The lines after the header.
Iterable<String> _content(String jsonl) => jsonl.split('\n').skip(1);

/// The examples of `lib/src/export_format_data.dart`: their header and that
/// they are valid sembast exports.
void main() {
  group('export_format_data', () {
    test('headers', () {
      expect(
        _firstLine(legacyExport1Jsonl),
        '{"sembast_export":1,"version":1}',
      );
      expect(
        _firstLine(sdbExport1Jsonl),
        '{"sdb_export":1,"sembast_export":1,"version":1}',
      );
      expect(
        _firstLine(idbDollarExport1Jsonl),
        r'{"sembast_export":1,"type_prefix":"$","version":1}',
      );
      expect(
        _firstLine(sdbDollarExport1Jsonl),
        r'{"sdb_export":1,"sembast_export":1,"type_prefix":"$","version":1}',
      );
      // Only the header differs between the idb and the sdb exports.
      expect(_content(sdbExport1Jsonl), _content(legacyExport1Jsonl));
      expect(_content(sdbDollarExport1Jsonl), _content(idbDollarExport1Jsonl));
    });

    test('types', () {
      expect(legacyExport1Jsonl, contains('{"@Timestamp":'));
      expect(legacyExport1Jsonl, contains('{"@Blob":'));
      expect(legacyExport1Jsonl, isNot(contains('type_prefix')));
      expect(legacyExport1Jsonl, isNot(contains('sdb_export')));
      expect(sdbDollarExport1Jsonl, contains(r'{"$Timestamp":'));
      expect(sdbDollarExport1Jsonl, contains(r'{"$Blob":'));
      expect(sdbDollarExport1Jsonl, isNot(contains('"@Blob"')));
    });

    test('valid sembast exports', () async {
      // A sembast import then export gives the legacy export (the sdb_export
      // marker is dropped), or the $ idb export with the $ encoding.
      for (var export in [
        legacyExport1Jsonl,
        sdbExport1Jsonl,
        idbDollarExport1Jsonl,
        sdbDollarExport1Jsonl,
      ]) {
        var db = await importDatabaseAny(
          export,
          newDatabaseFactoryMemory(),
          'imported.db',
        );
        try {
          expect(
            exportLinesToJsonlString(await exportDatabaseLines(db)),
            legacyExport1Jsonl,
          );
          expect(
            exportLinesToJsonlString(
              await exportDatabaseLines(
                db,
                options: const SembastExportOptions(
                  typeEncoding: SembastExportTypeEncoding.dollar,
                ),
              ),
            ),
            idbDollarExport1Jsonl,
          );
        } finally {
          await db.close();
        }
      }
    });
  });
}
