library;

import 'dart:typed_data';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_import_export.dart'
    show sdbExportDatabaseLinesGeneric;
import 'package:idb_shim/utils/sdb_import_export.dart';
import 'package:test/test.dart';

/// Any object, the memory factory does not look at it.
class _Handle {
  _Handle(this.name);

  final String name;
}

final _store = SdbStoreRef<String, SdbValue>('test');
final _indexedStore = SdbStoreRef<int, SdbModel>('indexed');
final _indexedStoreIndex = _indexedStore.index<String>('name');

/// The exported records of the store [name].
List<List> _records(List<Object> lines, String name) {
  var records = <List>[];
  String? store;
  for (var line in lines) {
    if (line is Map && line['store'] is String) {
      store = line['store'] as String;
    } else if (line is List && store == name) {
      records.add(line);
    }
  }
  return records;
}

String _handleName(SdbExportNativeValueContext context) =>
    (context.value.jsObject as _Handle).name;

void main() {
  group('sdb_export_native_value', () {
    var factory = newSdbFactoryMemory();
    var dbName = 'sdb_export_native_value.db';
    late SdbDatabase db;
    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 2,
          schema: SdbDatabaseSchema(
            stores: [
              _store.schema(),
              _indexedStore.schema(
                keyPath: SdbKeyPath.single('id'),
                autoIncrement: true,
                indexes: [
                  _indexedStoreIndex.schema(
                    keyPath: SdbKeyPath.single('name'),
                    unique: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
    tearDown(() async {
      await db.close();
    });

    Future<void> putAll() async {
      await _store.record('plain').put(db, {'value': 1});
      await _store.record('root').put(db, SdbNativeValue(_Handle('root')));
      await _store.record('nested').put(db, {
        'value': 2,
        'handle': SdbNativeValue(_Handle('handle')),
        'list': [1, SdbNativeValue(_Handle('item')), 3],
        'map': {
          'deep': [SdbNativeValue(_Handle('deep'))],
        },
      });
      await _indexedStore.add(db, {'name': 'other', 'value': 3});
    }

    test('no native value, same export', () async {
      await _store.record('plain').put(db, {'value': 1});
      await _store.record('bytes').put(db, Uint8List.fromList([1, 2]));
      await _indexedStore.add(db, {'name': 'other', 'value': 3});
      // idb export of the memory database vs sdb api export.
      var export = await sdbExportDatabaseLines(db);
      expect(await sdbExportDatabaseLinesGeneric(db), export);
      expect(
        await sdbExportDatabaseLines(
          db,
          nativeValueEncoder: (_) => fail('no native value'),
        ),
        export,
      );
    });
    test('value', () async {
      await putAll();
      var contexts = <SdbExportNativeValueContext>[];
      var lines = await sdbExportDatabaseLines(
        db,
        nativeValueEncoder: (context) async {
          contexts.add(context);
          // Can be asynchronous
          await Future<void>.delayed(Duration.zero);
          return {'handle': _handleName(context)};
        },
      );
      expect(
        contexts.map((c) => [c.storeName, c.key, c.path, _handleName(c)]),
        [
          [
            'test',
            'nested',
            ['handle'],
            'handle',
          ],
          [
            'test',
            'nested',
            ['list', 1],
            'item',
          ],
          [
            'test',
            'nested',
            ['map', 'deep', 0],
            'deep',
          ],
          ['test', 'root', <Object>[], 'root'],
        ],
      );
      expect(_records(lines, 'test'), [
        [
          'nested',
          {
            'value': 2,
            'handle': {'handle': 'handle'},
            'list': [
              1,
              {'handle': 'item'},
              3,
            ],
            'map': {
              'deep': [
                {'handle': 'deep'},
              ],
            },
          },
        ],
        [
          'plain',
          {'value': 1},
        ],
        [
          'root',
          {'handle': 'root'},
        ],
      ]);
      expect(_records(lines, 'indexed'), [
        [
          1,
          {'name': 'other', 'value': 3, 'id': 1},
        ],
      ]);

      // Imported back.
      var importedDb = await sdbImportDatabase(
        lines,
        factory,
        'sdb_export_native_value_imported.db',
      );
      expect(await _store.record('root').getValue(importedDb), {
        'handle': 'root',
      });
      expect(
        (await _indexedStoreIndex.record('other').getValue(importedDb))!['id'],
        1,
      );
      await importedDb.close();
    });
    test('bytes', () async {
      await _store.record('root').put(db, SdbNativeValue(_Handle('root')));
      var lines = await sdbExportDatabaseLines(
        db,
        nativeValueEncoder: (context) => Uint8List.fromList([1, 2]),
      );
      expect(_records(lines, 'test'), [
        [
          'root',
          {'@Blob': 'AQI='},
        ],
      ]);
    });
    test('null', () async {
      await putAll();
      var lines = await sdbExportDatabaseLines(
        db,
        nativeValueEncoder: (_) => null,
      );
      // A null record value drops the record.
      expect(_records(lines, 'test'), [
        [
          'nested',
          {
            'value': 2,
            'handle': null,
            'list': [1, null, 3],
            'map': {
              'deep': [null],
            },
          },
        ],
        [
          'plain',
          {'value': 1},
        ],
      ]);
    });
    test('drop', () async {
      await putAll();
      var lines = await sdbExportDatabaseLines(
        db,
        nativeValueEncoder: (_) => SdbExportNativeValue.drop,
      );
      expect(_records(lines, 'test'), [
        [
          'nested',
          {
            'value': 2,
            'list': [1, 3],
            'map': {'deep': <Object?>[]},
          },
        ],
        [
          'plain',
          {'value': 1},
        ],
      ]);
    });
    test('dropRecord', () async {
      await putAll();
      var lines = await sdbExportDatabaseLines(
        db,
        nativeValueEncoder: (context) => context.path.contains('deep')
            ? SdbExportNativeValue.dropRecord
            : 'kept',
      );
      expect(_records(lines, 'test'), [
        [
          'plain',
          {'value': 1},
        ],
        ['root', 'kept'],
      ]);
    });
    test('all dropped, store kept', () async {
      await _store.record('root').put(db, SdbNativeValue(_Handle('root')));
      var lines = await sdbExportDatabaseLines(
        db,
        nativeValueEncoder: (_) => SdbExportNativeValue.dropRecord,
      );
      expect(_records(lines, 'test'), isEmpty);
      var importedDb = await sdbImportDatabase(
        lines,
        factory,
        'sdb_export_native_value_imported.db',
      );
      expect(importedDb.storeNames, unorderedEquals(['test', 'indexed']));
      expect(await _store.count(importedDb), 0);
      await importedDb.close();
    });
    test('throw', () async {
      await putAll();
      await expectLater(
        () => sdbExportDatabaseLines(
          db,
          nativeValueEncoder: (_) => throw StateError('no export'),
        ),
        throwsA(isA<StateError>()),
      );
    });
    test('native value returned', () async {
      await putAll();
      await expectLater(
        () => sdbExportDatabaseLines(
          db,
          nativeValueEncoder: (context) => context.value,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
    test('no encoder', () async {
      await putAll();
      await expectLater(
        () => sdbExportDatabaseLines(db),
        throwsA(isA<ArgumentError>()),
      );
      // The sdb api export names the record.
      await expectLater(
        () => sdbExportDatabaseLinesGeneric(db),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('store test key nested path [handle]'),
          ),
        ),
      );
    });
  });
}
