library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:idb_shim/sdb.dart';
// ignore: implementation_imports
import 'package:idb_shim/src/sdb/sdb_database_impl.dart' show SdbDatabaseImpl;
// ignore: implementation_imports
import 'package:idb_shim/src/sdb/sdb_factory_impl.dart' show SdbFactoryIdb;
// ignore: implementation_imports
import 'package:idb_shim/src/sdb/sdb_import_export.dart'
    show sdbExportDatabaseLinesGeneric, sdbImportDatabaseGeneric;
import 'package:idb_shim/utils/idb_import_export.dart' as idb;
import 'package:idb_shim/utils/sdb_import_export.dart';
import 'package:sembast/utils/sembast_import_export.dart'
    show decodeImportAny, exportLinesToJsonlString;

import 'idb_test_common.dart';
import 'sdb_test.dart';
import 'src/export_format_data.dart';

void main() {
  sdbExportFormatTests(sdbMemoryContext);
}

final _noteStore = SdbStoreRef<int, SdbModel>('note');
final _noteTitleIndex = _noteStore.index<String>('title');
final _settingStore = SdbStoreRef<String, Object>('setting');

/// The note holding every type: DateTime, Uint8List, int (negative, the
/// biggest web safe one), double, bool, null, unicode text, nested and empty
/// lists and maps.
Map<String, Object?> _allTypesNote() => {
  'title': 'world',
  'date': DateTime.utc(2026, 11, 2, 12, 30),
  'bytes': Uint8List.fromList([1, 2, 3]),
  'int': -3,
  'bigInt': 9007199254740991,
  'double': 4.5,
  'true': true,
  'false': false,
  'null': null,
  'text': 'été ✓',
  'list': [
    1,
    [2, 'three'],
    <String, Object?>{},
    <Object?>[],
  ],
  'nested': {'done': true, 'empty': <String, Object?>{}},
};

/// The database of the examples (`src/export_format_data.dart`), 2 stores, 5
/// records: a store with a key path, auto increment and an index, a store
/// without, every type (see [_allTypesNote]) and maps looking like an encoded
/// type.
Future<SdbDatabase> sdbExportFormatCreateExample1(
  SdbFactory factory,
  String name,
) async {
  await factory.deleteDatabase(name);
  var db = await factory.openDatabase(
    name,
    options: SdbOpenDatabaseOptions(
      version: 2,
      schema: SdbDatabaseSchema(
        stores: [
          _noteStore.schema(
            keyPath: SdbKeyPath.single('id'),
            autoIncrement: true,
            indexes: [
              _noteTitleIndex.schema(keyPath: SdbKeyPath.single('title')),
            ],
          ),
          _settingStore.schema(),
        ],
      ),
    ),
  );
  await _noteStore.add(db, {
    'title': 'hello',
    'tags': ['a', 'b'],
  });
  await _noteStore.add(db, _allTypesNote());
  await _settingStore.record('theme').put(db, 'dark');
  await _settingStore.record('escaped_at').put(db, {
    '@Timestamp': 'not a timestamp',
  });
  await _settingStore.record('escaped_dollar').put(db, {
    r'$blob': 'not a blob',
  });
  return db;
}

/// The content of the example database, read through the sdb api.
///
/// [checkAutoIncrement] adds (then deletes) a record: the key generator does
/// not go back, call it once per imported database.
Future<void> sdbExportFormatCheckExample1(
  SdbDatabase db, {
  bool checkAutoIncrement = true,
}) async {
  expect(db.version, 2);
  expect(db.storeNames.toList()..sort(), ['note', 'setting']);
  expect(await _noteStore.record(1).getValue(db), {
    'id': 1,
    'title': 'hello',
    'tags': ['a', 'b'],
  });
  var world = (await _noteTitleIndex.record('world').getValue(db))!;
  expect(world, {..._allTypesNote(), 'id': 2});
  expect(world['date'], isA<DateTime>());
  expect(world['bytes'], isA<Uint8List>());
  expect(await _noteStore.count(db), 2);
  expect(await _settingStore.count(db), 3);
  expect((await _settingStore.record('theme').get(db))!.value, 'dark');
  expect((await _settingStore.record('escaped_at').get(db))!.value, {
    '@Timestamp': 'not a timestamp',
  });
  expect((await _settingStore.record('escaped_dollar').get(db))!.value, {
    r'$blob': 'not a blob',
  });
  if (checkAutoIncrement) {
    // The auto increment goes on after the imported keys.
    expect(await _noteStore.add(db, {'title': 'next'}), 3);
    await _noteStore.record(3).delete(db);
  }
}

/// The content of the example database, read through the idb api.
Future<void> _checkIdbExample1(idb.Database db) async {
  expect(db.version, 2);
  var txn = db.transaction(['note', 'setting'], idb.idbModeReadOnly);
  var notes = txn.objectStore('note');
  expect(notes.keyPath, 'id');
  expect(notes.autoIncrement, isTrue);
  expect(notes.indexNames, ['title']);
  var world = (await notes.index('title').get('world'))! as Map;
  expect(world['date'], DateTime.utc(2026, 11, 2, 12, 30));
  expect(world['bytes'], isA<Uint8List>());
  expect(await txn.objectStore('setting').getObject('theme'), 'dark');
  await txn.completed;
}

/// The jsonl sdb export of [db].
Future<String> sdbExportFormatSdbExportJsonl(
  SdbDatabase db, {
  SdbExportTypeEncoding? typeEncoding,
}) async => exportLinesToJsonlString(
  await sdbExportDatabaseLines(
    db,
    options: SdbExportOptions(typeEncoding: typeEncoding),
  ),
);

/// The jsonl generic sdb export of [db] (non idb sdb implementations).
Future<String> _sdbGenericExportJsonl(
  SdbDatabase db, {
  SdbExportTypeEncoding? typeEncoding,
}) async => exportLinesToJsonlString(
  await sdbExportDatabaseLinesGeneric(
    db,
    options: SdbExportOptions(typeEncoding: typeEncoding),
  ),
);

/// The jsonl idb export of [db].
Future<String> sdbExportFormatIdbExportJsonl(
  idb.Database db, {
  idb.IdbExportTypeEncoding? typeEncoding,
}) async => exportLinesToJsonlString(
  await idb.idbExportDatabaseLines(
    db,
    options: idb.IdbExportOptions(typeEncoding: typeEncoding),
  ),
);

const _iso = '2026-11-02T12:30:00.000Z';
final _dateTime = DateTime.parse(_iso);
final _bytes = Uint8List.fromList([1, 2, 3]);
const _bytesBase64 = 'AQID';

const _legacyHeader = {'sembast_export': 1, 'version': 1};
Map<String, Object?> _header(String prefix) => {
  ..._legacyHeader,
  'type_prefix': prefix,
};

/// An export of one store `s` holding the record `k`: `{'v': [encoded]}`.
List<Object> _oneValueLines(Map header, Object encoded) => [
  header,
  {'store': '_main'},
  [
    'store_s',
    {'name': 's'},
  ],
  [
    'stores',
    ['s'],
  ],
  ['version', 1],
  {'store': 's'},
  [
    'k',
    {'v': encoded},
  ],
];

final _oneValueStore = SdbStoreRef<String, SdbModel>('s');

/// The export formats (`src/export_format_data.dart`) with any sdb factory:
/// legacy export, sdb export, `$` exports, `$`/`@` combinations of an
/// import.
void sdbExportFormatTests(SdbTestContext ctx) {
  var factory = ctx.factory;
  var idbFactory = factory is SdbFactoryIdb ? factory.idbFactory : null;
  const at = SdbExportTypeEncoding.at;
  const dollar = SdbExportTypeEncoding.dollar;

  group('sdb_export_format', () {
    var example1DbName = 'export_format_example1.db';
    var importedDbName = 'export_format_imported.db';
    var genericDbName = 'export_format_generic.db';
    var idbDbName = 'export_format_idb.db';

    /// Import [data] with [sdbImportDatabase] (idb based for an idb factory)
    /// and with the generic sdb import, check the content and run [check]
    /// on each imported database.
    Future<void> sdbImportBoth(
      Object data,
      Future<void> Function(SdbDatabase db) check, {
      List<SdbExportTypeEncoding>? allowedTypeEncodings,
    }) async {
      for (var (name, import) in [
        (
          'sdb',
          () => sdbImportDatabase(
            data,
            factory,
            importedDbName,
            options: SdbImportOptions(
              allowedTypeEncodings: allowedTypeEncodings,
            ),
          ),
        ),
        (
          'generic',
          () => sdbImportDatabaseGeneric(
            decodeImportAny(data),
            factory,
            genericDbName,
            options: SdbImportOptions(
              allowedTypeEncodings: allowedTypeEncodings,
            ),
          ),
        ),
      ]) {
        var db = await import();
        try {
          await sdbExportFormatCheckExample1(db);
          await check(db);
        } catch (e) {
          // ignore: avoid_print
          print('$name import failed');
          rethrow;
        } finally {
          await db.close();
        }
      }
    }

    /// Every import of [data] restricted to [allowedTypeEncodings] throws a
    /// FormatException.
    Future<void> importAllThrow(
      Object data,
      List<SdbExportTypeEncoding> allowedTypeEncodings,
    ) async {
      await expectLater(
        () => sdbImportDatabase(
          data,
          factory,
          importedDbName,
          options: SdbImportOptions(allowedTypeEncodings: allowedTypeEncodings),
        ),
        throwsFormatException,
      );
      await expectLater(
        () => sdbImportDatabaseGeneric(
          decodeImportAny(data),
          factory,
          genericDbName,
          options: SdbImportOptions(allowedTypeEncodings: allowedTypeEncodings),
        ),
        throwsFormatException,
      );
      if (idbFactory != null) {
        await expectLater(
          () => idb.idbImportDatabase(
            data,
            idbFactory,
            idbDbName,
            options: SdbImportOptions(
              allowedTypeEncodings: allowedTypeEncodings,
            ),
          ),
          throwsFormatException,
        );
      }
    }

    group('legacy export', () {
      test('export', () async {
        var db = await sdbExportFormatCreateExample1(factory, example1DbName);
        try {
          if (db is SdbDatabaseImpl) {
            var idbDb = db.idbDatabase;
            expect(
              await sdbExportFormatIdbExportJsonl(idbDb),
              legacyExport1Jsonl,
            );
            expect(
              await sdbExportFormatIdbExportJsonl(idbDb, typeEncoding: at),
              legacyExport1Jsonl,
            );
            var map = await idb.idbExportDatabase(idbDb);
            expect(map['sembast_export'], 1);
            expect(map.containsKey('type_prefix'), isFalse);
          }
        } finally {
          await db.close();
        }
      });

      test('sdb import, re-export', () async {
        for (var allowed in [
          null,
          [at],
          SdbExportTypeEncoding.values,
        ]) {
          await sdbImportBoth(legacyExport1Jsonl, (db) async {
            expect(await _sdbGenericExportJsonl(db), sdbExport1Jsonl);
            expect(await sdbExportFormatSdbExportJsonl(db), sdbExport1Jsonl);
            if (db is SdbDatabaseImpl) {
              expect(
                await sdbExportFormatIdbExportJsonl(db.idbDatabase),
                legacyExport1Jsonl,
              );
            }
          }, allowedTypeEncodings: allowed);
        }
      });

      if (idbFactory != null) {
        test('idb import, re-export', () async {
          var db = await idb.idbImportDatabase(
            legacyExport1Jsonl,
            idbFactory,
            idbDbName,
          );
          try {
            await _checkIdbExample1(db);
            expect(await sdbExportFormatIdbExportJsonl(db), legacyExport1Jsonl);
            expect(
              await sdbExportFormatIdbExportJsonl(db, typeEncoding: dollar),
              idbDollarExport1Jsonl,
            );
          } finally {
            db.close();
          }
        });
      }

      test('import restricted to dollar', () async {
        await importAllThrow(legacyExport1Jsonl, [dollar]);
      });
    });

    group('sdb export', () {
      test('export', () async {
        var db = await sdbExportFormatCreateExample1(factory, example1DbName);
        try {
          expect(await sdbExportFormatSdbExportJsonl(db), sdbExport1Jsonl);
          expect(
            await sdbExportFormatSdbExportJsonl(db, typeEncoding: at),
            sdbExport1Jsonl,
          );
          expect(await _sdbGenericExportJsonl(db), sdbExport1Jsonl);
        } finally {
          await db.close();
        }
      });

      test('import, re-export', () async {
        await sdbImportBoth(sdbExport1Jsonl, (db) async {
          expect(await _sdbGenericExportJsonl(db), sdbExport1Jsonl);
          expect(await sdbExportFormatSdbExportJsonl(db), sdbExport1Jsonl);
        });
      });

      test('re-export after reopen', () async {
        var db = await sdbImportDatabase(
          sdbExport1Jsonl,
          factory,
          importedDbName,
        );
        await db.close();
        db = await factory.openDatabase(importedDbName);
        try {
          await sdbExportFormatCheckExample1(db, checkAutoIncrement: false);
          expect(await sdbExportFormatSdbExportJsonl(db), sdbExport1Jsonl);
        } finally {
          await db.close();
        }
      });

      test('newer sdb export', () async {
        var lines = decodeImportAny(sdbExport1Jsonl) as List;
        lines[0] = {'sembast_export': 1, 'version': 1, 'sdb_export': 2};
        await expectLater(
          () => sdbImportDatabase(lines, factory, importedDbName),
          throwsFormatException,
        );
        await expectLater(
          () => sdbImportDatabaseGeneric(lines, factory, genericDbName),
          throwsFormatException,
        );
      });
    });

    group('dollar export', () {
      test('export', () async {
        var db = await sdbExportFormatCreateExample1(factory, example1DbName);
        try {
          expect(
            await sdbExportFormatSdbExportJsonl(db, typeEncoding: dollar),
            sdbDollarExport1Jsonl,
          );
          expect(
            await _sdbGenericExportJsonl(db, typeEncoding: dollar),
            sdbDollarExport1Jsonl,
          );
          if (db is SdbDatabaseImpl) {
            var idbDb = db.idbDatabase;
            expect(
              await sdbExportFormatIdbExportJsonl(idbDb, typeEncoding: dollar),
              idbDollarExport1Jsonl,
            );
            var map = await idb.idbExportDatabase(
              idbDb,
              options: const idb.IdbExportOptions(typeEncoding: dollar),
            );
            expect(map['type_prefix'], r'$');
          }
        } finally {
          await db.close();
        }
      });

      test('sdb import, re-export', () async {
        for (var export in [sdbDollarExport1Jsonl, idbDollarExport1Jsonl]) {
          for (var allowed in [
            null,
            [dollar],
          ]) {
            await sdbImportBoth(export, (db) async {
              expect(
                await _sdbGenericExportJsonl(db, typeEncoding: dollar),
                sdbDollarExport1Jsonl,
              );
              expect(await _sdbGenericExportJsonl(db), sdbExport1Jsonl);
              expect(
                await sdbExportFormatSdbExportJsonl(db, typeEncoding: dollar),
                sdbDollarExport1Jsonl,
              );
              expect(await sdbExportFormatSdbExportJsonl(db), sdbExport1Jsonl);
              if (db is SdbDatabaseImpl) {
                expect(
                  await sdbExportFormatIdbExportJsonl(db.idbDatabase),
                  legacyExport1Jsonl,
                );
              }
            }, allowedTypeEncodings: allowed);
          }
        }
      });

      if (idbFactory != null) {
        test('idb import, re-export', () async {
          var db = await idb.idbImportDatabase(
            idbDollarExport1Jsonl,
            idbFactory,
            idbDbName,
          );
          try {
            await _checkIdbExample1(db);
            expect(
              await sdbExportFormatIdbExportJsonl(db, typeEncoding: dollar),
              idbDollarExport1Jsonl,
            );
            expect(await sdbExportFormatIdbExportJsonl(db), legacyExport1Jsonl);
          } finally {
            db.close();
          }
        });
      }

      test('import restricted to at', () async {
        await importAllThrow(sdbDollarExport1Jsonl, [at]);
        await importAllThrow(idbDollarExport1Jsonl, [at]);
      });
    });

    group('transaction', () {
      /// The records of [store] in the export [lines].
      List<List> storeLines(List<Object> lines, String store) {
        var records = <List>[];
        String? current;
        for (var line in lines) {
          if (line is Map && line['store'] is String) {
            current = line['store'] as String;
          } else if (line is List && current == store) {
            records.add(line);
          }
        }
        return records;
      }

      test('read only, same as the database', () async {
        var db = await sdbExportFormatCreateExample1(factory, example1DbName);
        try {
          await db.inStoresTransaction(
            [_noteStore, _settingStore],
            SdbTransactionMode.readOnly,
            (txn) async {
              expect(
                exportLinesToJsonlString(await sdbExportDatabaseLines(txn)),
                sdbExport1Jsonl,
              );
              expect(
                exportLinesToJsonlString(
                  await sdbExportDatabaseLines(
                    txn,
                    options: const SdbExportOptions(typeEncoding: dollar),
                  ),
                ),
                sdbDollarExport1Jsonl,
              );
            },
          );
        } finally {
          await db.close();
        }
      });

      test('write and export in the same transaction', () async {
        var db = await sdbExportFormatCreateExample1(factory, example1DbName);
        try {
          late List<Object> txnExport;
          await db.inStoresTransaction(
            [_noteStore, _settingStore],
            SdbTransactionMode.readWrite,
            (txn) async {
              await _settingStore.record('extra').put(txn, 'value');
              await _settingStore.record('theme').delete(txn);
              txnExport = await sdbExportDatabaseLines(txn);
              // The transaction is still usable.
              await _settingStore.record('after').put(txn, 'export');
            },
          );
          var settings = storeLines(txnExport, 'setting');
          expect(settings, contains(equals(['extra', 'value'])));
          expect(settings.map((line) => line.first), isNot(contains('theme')));
          expect(settings.map((line) => line.first), isNot(contains('after')));
          expect(
            storeLines(await sdbExportDatabaseLines(db), 'setting'),
            [
              ...settings,
              ['after', 'export'],
            ]..sort((a, b) => (a.first as String).compareTo(b.first as String)),
          );
        } finally {
          await db.close();
        }
      });

      test('the stores of the transaction', () async {
        var db = await sdbExportFormatCreateExample1(factory, example1DbName);
        try {
          await db.inStoresTransaction(
            [_settingStore],
            SdbTransactionMode.readOnly,
            (txn) async {
              var lines = await sdbExportDatabaseLines(txn);
              expect(
                lines,
                contains(
                  equals([
                    'stores',
                    ['setting'],
                  ]),
                ),
              );
              expect(lines, contains(equals({'store': 'setting'})));
              expect(lines, isNot(contains(equals({'store': 'note'}))));
            },
          );
        } finally {
          await db.close();
        }
      });
    });

    group('type encoding', () {
      // The $ and @ combinations: header (legacy: none, type_prefix @,
      // type_prefix $) x encoded value spelling (prefix, case), read through
      // idb (DateTime, Uint8List) and the same through the idb based and the
      // generic sdb imports.
      // (header name, header, encoded, expected idb value)
      var cases = <(String, Map, Object, Object Function())>[
        // Legacy: the name case must match exactly.
        ...[
          ({'@Timestamp': _iso}, () => _dateTime),
          ({'@Blob': _bytesBase64}, () => _bytes),
          ({'@timestamp': _iso}, () => {'@timestamp': _iso}),
          ({r'$timestamp': _iso}, () => {r'$timestamp': _iso}),
          ({r'$blob': _bytesBase64}, () => {r'$blob': _bytesBase64}),
        ].map((c) => ('legacy', _legacyHeader, c.$1, c.$2)),
        // type_prefix $: the type names as is (no case conversion), an @ key
        // is data.
        ...[
          ({r'$Timestamp': _iso}, () => _dateTime),
          ({r'$Blob': _bytesBase64}, () => _bytes),
          ({r'$timestamp': _iso}, () => {r'$timestamp': _iso}),
          ({r'$blob': _bytesBase64}, () => {r'$blob': _bytesBase64}),
          ({r'$TIMESTAMP': _iso}, () => {r'$TIMESTAMP': _iso}),
          ({'@Blob': _bytesBase64}, () => {'@Blob': _bytesBase64}),
          ({r'$foo': 1}, () => {r'$foo': 1}),
        ].map((c) => (r'type_prefix $', _header(r'$'), c.$1, c.$2)),
        // type_prefix @: the type names as is, a $ key is data.
        ...[
          ({'@Timestamp': _iso}, () => _dateTime),
          ({'@Blob': _bytesBase64}, () => _bytes),
          ({'@timestamp': _iso}, () => {'@timestamp': _iso}),
          ({'@blob': _bytesBase64}, () => {'@blob': _bytesBase64}),
          ({r'$timestamp': _iso}, () => {r'$timestamp': _iso}),
        ].map((c) => ('type_prefix @', _header('@'), c.$1, c.$2)),
      ];

      for (var (headerName, header, encoded, expected) in cases) {
        test('$headerName ${jsonEncode(encoded)}', () async {
          var lines = _oneValueLines(header, encoded);

          if (idbFactory != null) {
            // Through idb: the native types.
            var idbDb = await idb.idbImportDatabase(
              lines,
              idbFactory,
              idbDbName,
            );
            try {
              var txn = idbDb.transaction('s', idb.idbModeReadOnly);
              var value = (await txn.objectStore('s').getObject('k'))! as Map;
              await txn.completed;
              expect(value['v'], expected());
            } finally {
              idbDb.close();
            }
          }

          // The sdb import (idb based for an idb factory) and the generic
          // one read the same.
          var sdbDb = await sdbImportDatabase(lines, factory, importedDbName);
          var genericDb = await sdbImportDatabaseGeneric(
            lines,
            factory,
            genericDbName,
          );
          try {
            var sdbValue = await _oneValueStore.record('k').getValue(sdbDb);
            expect(
              await _oneValueStore.record('k').getValue(genericDb),
              sdbValue,
            );
            var expectedValue = expected();
            if (expectedValue is DateTime || expectedValue is Uint8List) {
              expect(sdbValue!['v'], expectedValue);
            }
          } finally {
            await sdbDb.close();
            await genericDb.close();
          }
        });
      }
    });
  });
}
