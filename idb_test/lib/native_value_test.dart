library;

import 'package:idb_shim/utils/idb_import_export.dart';
import 'package:idb_shim/utils/idb_utils.dart';

import 'idb_test_common.dart';
import 'src/test_native_object.dart';

void main() {
  defineTests(idbMemoryContext);
}

const _storeName = 'native_value';
const _indexName = 'index';

IdbNativeValue _nativeValue() => IdbNativeValue(newTestNativeObject());

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  group('native_value', () {
    late String dbName;
    Database? db;
    Future<Database> openDb() async {
      dbName = ctx.dbName;
      await idbFactory.deleteDatabase(dbName);
      return db = await idbFactory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (event) {
          event.database
              .createObjectStore(_storeName)
              .createIndex(_indexName, 'index');
        },
      );
    }

    tearDown(() {
      db?.close();
      db = null;
    });

    Future<T> inStore<T>(
      Database db,
      Future<T> Function(ObjectStore store) action, {
      String mode = idbModeReadWrite,
    }) async {
      var txn = db.transaction(_storeName, mode);
      var result = await action(txn.objectStore(_storeName));
      await txn.completed;
      return result;
    }

    Future<Object?> get(Database db, Object key) =>
        inStore(db, (store) => store.getObject(key), mode: idbModeReadOnly);

    if (ctx.supportsNativeValue) {
      test('put get', () async {
        var db = await openDb();
        await inStore(db, (store) async {
          await store.put(_nativeValue(), 'root');
          await store.put({
            'list': [_nativeValue()],
            'map': {'value': _nativeValue()},
          }, 'nested');
        });
        expect(await get(db, 'root'), isA<IdbNativeValue>());
        var nested = (await get(db, 'nested'))! as Map;
        expect((nested['list'] as List).first, isA<IdbNativeValue>());
        expect((nested['map'] as Map)['value'], isA<IdbNativeValue>());
        var (all, cursorValues) = await inStore(
          db,
          (store) async => (
            await store.getAll(),
            await store
                .openCursor(autoAdvance: true)
                .map((cwv) => cwv.value)
                .toList(),
          ),
          mode: idbModeReadOnly,
        );
        expect(all, hasLength(2));
        expect(cursorValues.last, isA<IdbNativeValue>());
      });
      test('index', () async {
        var db = await openDb();
        await inStore(db, (store) async {
          // Not a valid key, not indexed.
          await store.put({'index': _nativeValue()}, 'native');
          await store.put({'index': 1, 'value': _nativeValue()}, 'indexed');
        });
        var (count, value) = await inStore(db, (store) async {
          var index = store.index(_indexName);
          return (await index.count(), await index.get(1));
        }, mode: idbModeReadOnly);
        expect(count, 1);
        expect((value as Map)['value'], isA<IdbNativeValue>());
      });
      test('export', () async {
        var db = await openDb();
        await inStore(db, (store) async {
          await store.put({'value': 1}, 'plain');
          await store.put(_nativeValue(), 'root');
          await store.put({'value': 2, 'native': _nativeValue()}, 'nested');
        });
        await expectLater(
          () => idbExportDatabaseLines(db),
          throwsA(isA<ArgumentError>()),
        );
        var lines = await idbExportDatabaseLines(
          db,
          nativeValueEncoder: (context) async {
            await Future<void>.delayed(Duration.zero);
            return context.path.isEmpty
                ? IdbExportNativeValue.drop
                : 'native ${context.key}';
          },
        );
        var importedDbName = 'imported_$dbName';
        var importedDb = await idbImportDatabase(
          lines,
          idbFactory,
          importedDbName,
        );
        try {
          expect(await get(importedDb, 'plain'), {'value': 1});
          expect(await get(importedDb, 'root'), isNull);
          expect(await get(importedDb, 'nested'), {
            'value': 2,
            'native': 'native nested',
          });
        } finally {
          importedDb.close();
        }
      });
    } else {
      test('put rejected', () async {
        var db = await openDb();
        var txn = db.transaction(_storeName, idbModeReadWrite);
        var store = txn.objectStore(_storeName);
        await expectLater(
          () => store.put(_nativeValue(), 'key'),
          throwsA(isA<ArgumentError>()),
        );
        try {
          await txn.completed;
        } catch (_) {}
        expect(
          await inStore(db, (store) => store.count(), mode: idbModeReadOnly),
          0,
        );
      });
      test('copy rejected', () async {
        dbName = ctx.dbName;
        var srcDb = await newIdbFactoryMemory().open(
          dbName,
          version: 1,
          onUpgradeNeeded: (event) {
            event.database.createObjectStore(_storeName);
          },
        );
        await inStore(srcDb, (store) async {
          await store.put({'value': 1}, 'a');
          await store.put(_nativeValue(), 'b');
          await store.put({'value': 2}, 'c');
        });
        var dstDbName = 'dst_$dbName';
        await idbFactory.deleteDatabase(dstDbName);
        // The put error, not the transaction abort one.
        await expectLater(
          () => copyDatabase(srcDb, idbFactory, dstDbName),
          throwsA(isA<ArgumentError>()),
        );
        srcDb.close();
      });
      test('export encoder not called', () async {
        var db = await openDb();
        await inStore(db, (store) => store.put({'value': 1}, 'plain'));
        expect(
          await idbExportDatabaseLines(
            db,
            nativeValueEncoder: (_) => fail('no native value'),
          ),
          await idbExportDatabaseLines(db),
        );
      });
    }
  });
}
