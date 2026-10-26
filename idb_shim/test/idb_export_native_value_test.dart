library;

import 'dart:typed_data';

import 'package:idb_shim/utils/idb_import_export.dart';
import 'package:test/test.dart';

/// Any object, the memory factory does not look at it.
class _Handle {
  _Handle(this.name);

  final String name;
}

const _storeName = 'test';
const _keyPathStoreName = 'key_path';
const _indexName = 'name';

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

String _handleName(IdbExportNativeValueContext context) =>
    (context.value.jsObject as _Handle).name;

void main() {
  group('idb_export_native_value', () {
    var factory = newIdbFactoryMemory();
    var dbName = 'idb_export_native_value.db';
    var importedDbName = 'idb_export_native_value_imported.db';
    late Database db;
    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (event) {
          event.database.createObjectStore(_storeName);
          event.database
              .createObjectStore(
                _keyPathStoreName,
                keyPath: 'id',
                autoIncrement: true,
              )
              .createIndex(_indexName, 'name', unique: true);
        },
      );
    });
    tearDown(() {
      db.close();
    });
    Future<void> put(String storeName, Object value, [Object? key]) async {
      var txn = db.transaction(storeName, idbModeReadWrite);
      await txn.objectStore(storeName).put(value, key);
      await txn.completed;
    }

    Future<Object?> get(Database db, String storeName, Object key) async {
      var txn = db.transaction(storeName, idbModeReadOnly);
      var value = await txn.objectStore(storeName).getObject(key);
      await txn.completed;
      return value;
    }

    Future<void> putAll() async {
      await put(_storeName, {'value': 1}, 'plain');
      await put(_storeName, IdbNativeValue(_Handle('root')), 'root');
      await put(_storeName, {
        'value': 2,
        'handle': IdbNativeValue(_Handle('handle')),
        'list': [1, IdbNativeValue(_Handle('item')), 3],
      }, 'nested');
      await put(_keyPathStoreName, {
        'name': 'key_path',
        'handle': IdbNativeValue(_Handle('key_path')),
      });
    }

    test('no native value, same export', () async {
      await put(_storeName, {'value': 1}, 'plain');
      await put(_storeName, Uint8List.fromList([1, 2]), 'bytes');
      await put(_storeName, DateTime.utc(2020), 'date');
      await put(_keyPathStoreName, {'name': 'other'});
      var export = await idbExportDatabaseLines(db);
      expect(
        await idbExportDatabaseLines(
          db,
          nativeValueEncoder: (_) => fail('no native value'),
        ),
        export,
      );
      expect(
        await idbExportDatabase(
          db,
          nativeValueEncoder: (_) => fail('no native value'),
        ),
        await idbExportDatabase(db),
      );
    });
    test('value', () async {
      await putAll();
      var contexts = <IdbExportNativeValueContext>[];
      var lines = await idbExportDatabaseLines(
        db,
        nativeValueEncoder: (context) async {
          contexts.add(context);
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
          ['test', 'root', <Object>[], 'root'],
          [
            'key_path',
            1,
            ['handle'],
            'key_path',
          ],
        ],
      );
      expect(_records(lines, _storeName), [
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
      expect(_records(lines, _keyPathStoreName), [
        [
          1,
          {
            'name': 'key_path',
            'handle': {'handle': 'key_path'},
            'id': 1,
          },
        ],
      ]);
      // The source database is unchanged.
      expect(await get(db, _storeName, 'root'), isA<IdbNativeValue>());

      // Imported back, the index too.
      var importedDb = await idbImportDatabase(lines, factory, importedDbName);
      expect(await get(importedDb, _storeName, 'root'), {'handle': 'root'});
      var txn = importedDb.transaction(_keyPathStoreName, idbModeReadOnly);
      var index = txn.objectStore(_keyPathStoreName).index(_indexName);
      expect(await index.getKey('key_path'), 1);
      await txn.completed;
      importedDb.close();
    });
    test('map export', () async {
      await put(_storeName, IdbNativeValue(_Handle('root')), 'root');
      var export = await idbExportDatabase(
        db,
        nativeValueEncoder: (context) => Uint8List.fromList([1, 2]),
      );
      var importedDb = await idbImportDatabase(export, factory, importedDbName);
      expect(await get(importedDb, _storeName, 'root'), [1, 2]);
      importedDb.close();
    });
    test('null', () async {
      await putAll();
      var lines = await idbExportDatabaseLines(
        db,
        nativeValueEncoder: (_) => null,
      );
      // A null record value drops the record.
      expect(_records(lines, _storeName), [
        [
          'nested',
          {
            'value': 2,
            'handle': null,
            'list': [1, null, 3],
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
      var lines = await idbExportDatabaseLines(
        db,
        nativeValueEncoder: (_) => IdbExportNativeValue.drop,
      );
      expect(_records(lines, _storeName), [
        [
          'nested',
          {
            'value': 2,
            'list': [1, 3],
          },
        ],
        [
          'plain',
          {'value': 1},
        ],
      ]);
      expect(_records(lines, _keyPathStoreName), [
        [
          1,
          {'name': 'key_path', 'id': 1},
        ],
      ]);
    });
    test('dropRecord', () async {
      await putAll();
      var lines = await idbExportDatabaseLines(
        db,
        nativeValueEncoder: (context) =>
            context.path.isEmpty ? 'kept' : IdbExportNativeValue.dropRecord,
      );
      expect(_records(lines, _storeName), [
        [
          'plain',
          {'value': 1},
        ],
        ['root', 'kept'],
      ]);
      expect(_records(lines, _keyPathStoreName), isEmpty);
    });
    test('throw', () async {
      await putAll();
      await expectLater(
        () => idbExportDatabaseLines(
          db,
          nativeValueEncoder: (_) => throw StateError('no export'),
        ),
        throwsA(isA<StateError>()),
      );
    });
    test('native value returned', () async {
      await putAll();
      await expectLater(
        () => idbExportDatabaseLines(
          db,
          nativeValueEncoder: (context) => context.value,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
    test('no encoder', () async {
      await putAll();
      await expectLater(
        () => idbExportDatabaseLines(db),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => idbExportDatabase(db),
        throwsA(isA<ArgumentError>()),
      );
    });
    test('storage factory, encoder not called', () async {
      var storageDb = await idbFactoryMemoryFs.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (event) {
          event.database.createObjectStore(_storeName);
        },
      );
      var txn = storageDb.transaction(_storeName, idbModeReadWrite);
      await txn.objectStore(_storeName).put({'value': 1}, 'plain');
      await txn.completed;
      expect(
        await idbExportDatabaseLines(
          storageDb,
          nativeValueEncoder: (_) => fail('no native value'),
        ),
        await idbExportDatabaseLines(storageDb),
      );
      storageDb.close();
      await idbFactoryMemoryFs.deleteDatabase(dbName);
    });
  });
}
