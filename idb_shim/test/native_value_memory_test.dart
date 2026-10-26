library;

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/utils/idb_import_export.dart';
import 'package:idb_shim/utils/idb_utils.dart';
import 'package:idb_shim/utils/sdb_import_export.dart';
import 'package:test/test.dart';

/// Any object, the memory factory does not look at it.
class _Handle {
  @override
  String toString() => 'Handle';
}

const _storeName = 'test';
const _indexName = 'index';

Future<Database> _openDb(IdbFactory factory) async {
  var dbName = 'native_value_memory.db';
  await factory.deleteDatabase(dbName);
  return await factory.open(
    dbName,
    version: 1,
    onUpgradeNeeded: (event) {
      var store = event.database.createObjectStore(_storeName);
      store.createIndex(_indexName, 'index');
    },
  );
}

void main() {
  group('native_value_memory', () {
    late Database db;
    setUp(() async {
      db = await _openDb(newIdbFactoryMemory());
    });
    tearDown(() {
      db.close();
    });
    Future<T> inStore<T>(
      Future<T> Function(ObjectStore store) action, {
      String mode = idbModeReadWrite,
    }) async {
      var txn = db.transaction(_storeName, mode);
      var result = await action(txn.objectStore(_storeName));
      await txn.completed;
      return result;
    }

    test('idb put get', () async {
      var handle = _Handle();
      await inStore((store) async {
        await store.put(IdbNativeValue(handle), 'root');
        await store.add({
          'list': [IdbNativeValue(handle)],
          'map': {'value': IdbNativeValue(handle)},
        }, 'nested');
      });
      var (root, nested, all) = await inStore(
        (store) async => (
          await store.getObject('root'),
          await store.getObject('nested'),
          await store.getAll(),
        ),
        mode: idbModeReadOnly,
      );
      // Same object, no copy.
      expect((root as IdbNativeValue).jsObject, same(handle));
      var map = nested as Map;
      expect(((map['list'] as List).first as IdbNativeValue).jsObject, handle);
      expect(((map['map'] as Map)['value'] as IdbNativeValue).jsObject, handle);
      expect(all, hasLength(2));
    });
    test('cursor update', () async {
      var handle = _Handle();
      await inStore((store) async {
        await store.put({'value': 1}, 'key');
        await store.openCursor(autoAdvance: false).listen((cwv) {
          cwv.update({'value': IdbNativeValue(handle)});
          cwv.next();
        }).asFuture<void>();
      });
      var values = await inStore(
        (store) async => [
          await for (var cwv in store.openCursor(autoAdvance: true)) cwv.value,
        ],
        mode: idbModeReadOnly,
      );
      expect((values.single as Map)['value'], isA<IdbNativeValue>());
    });
    test('index', () async {
      await inStore((store) async {
        // Not a valid key, not indexed.
        await store.put({'index': IdbNativeValue(_Handle())}, 'native');
        await store.put({
          'index': 1,
          'value': IdbNativeValue(_Handle()),
        }, 'indexed');
      });
      var (count, value) = await inStore((store) async {
        var index = store.index(_indexName);
        return (await index.count(), await index.get(1));
      }, mode: idbModeReadOnly);
      expect(count, 1);
      expect((value as Map)['value'], isA<IdbNativeValue>());
    });
    test('sdb put get', () async {
      var store = SdbStoreRef<String, SdbModel>('test');
      var sdb = await newSdbFactoryMemory().openDatabase(
        'native_value_memory.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [store.schema()]),
        ),
      );
      var handle = _Handle();
      await store.record('key').put(sdb, {'value': SdbNativeValue(handle)});
      var value = await store.record('key').getValue(sdb);
      expect((value!['value'] as SdbNativeValue).jsObject, same(handle));
      await expectLater(
        () => sdbExportDatabaseLines(sdb),
        throwsA(isA<ArgumentError>()),
      );
      await sdb.close();
    });
    test('export rejected', () async {
      await inStore((store) => store.put(IdbNativeValue(_Handle()), 'key'));
      await expectLater(
        () => idbExportDatabaseLines(db),
        throwsA(isA<ArgumentError>()),
      );
    });
    test('copy to storage rejected', () async {
      await inStore((store) async {
        await store.put({'value': 1}, 'a');
        await store.put(IdbNativeValue(_Handle()), 'b');
        await store.put({'value': 2}, 'c');
      });
      // The put error, not the transaction abort one, and no uncaught error.
      await expectLater(
        () => copyDatabase(db, idbFactoryMemoryFs, 'native_value_copy.db'),
        throwsA(isA<ArgumentError>()),
      );
    });
    test('toString', () {
      expect(IdbNativeValue('value').toString(), 'IdbNativeValue(value)');
    });
  });
  group('native_value_memory_fs', () {
    test('idb put rejected', () async {
      var db = await _openDb(idbFactoryMemoryFs);
      var txn = db.transaction(_storeName, idbModeReadWrite);
      var store = txn.objectStore(_storeName);
      // Listened right away, the errors come in a row.
      var putOk = store.put({'value': 1}, 'a');
      var putNative = expectLater(
        store.put(IdbNativeValue(_Handle()), 'b'),
        throwsA(isA<ArgumentError>()),
      );
      // Aborted, the following requests are not run.
      var putAfter = expectLater(
        store.put({'value': 2}, 'c'),
        throwsA(isA<DatabaseException>()),
      );
      var completed = expectLater(
        txn.completed,
        throwsA(isA<DatabaseException>()),
      );
      expect(await putOk, 'a');
      await Future.wait([putNative, putAfter, completed]);
      txn = db.transaction(_storeName, idbModeReadOnly);
      expect(await txn.objectStore(_storeName).count(), 0);
      await txn.completed;
      db.close();
    });
  });
}
