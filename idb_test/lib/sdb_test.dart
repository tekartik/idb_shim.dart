import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:idb_shim/sdb/sdb.dart';

import 'package:test/test.dart';

void main() {
  IdbFactoryLogger.debugMaxLogCount = 100;
  var idbFactory = idb.idbFactoryMemoryFs;
  idbFactory = getIdbFactoryLogger(idbFactory);
  var factory = sdbFactoryFromIdb(idbFactory);
  simpleDbTest(factory);
}

var testStore = SdbStoreRef<int, SdbModel>('test');
var testIndex = testStore.index<int>('myindex');
var testStore2 = SdbStoreRef<String, SdbModel>('test2');

void simpleDbTest(SdbFactory factory) {
  test('open/close', () async {
    var db = await factory.openDatabase('test.db');
    await db.close();
  });
  group('int key', () {
    test('put/get/delete int', () async {
      await factory.deleteDatabase('test_put_get.db');
      var db = await factory.openDatabase('test_put_get.db', version: 1,
          onVersionChange: (event) {
        var oldVersion = event.oldVersion;
        if (oldVersion < 1) {
          event.db.createStore(testStore);
        }
      });
      var key = await testStore.add(db, {'test': 1});
      expect(key, 1);
      var key2 = await testStore.add(db, {'test': 2});
      expect(key2, 2);
      var record = (await testStore.record(key).get(db))!;
      expect(record.value, {'test': 1});
      expect(record.key, key);
      record = (await testStore.record(key2).get(db))!;
      expect(record.value, {'test': 2});
      expect(await testStore.record(3).get(db), isNull);
      await testStore.record(key).delete(db);
      expect(await testStore.record(key).get(db), isNull);
      await testStore.record(key).put(db, {'test': 3});
      record = (await testStore.record(key).get(db))!;
      expect(record.value, {'test': 3});
      expect(record.key, key);
      await db.close();
    });
    test('txn put/get/delete int', () async {
      await factory.deleteDatabase('test_put_get.db');
      var db = await factory.openDatabase('test_put_get.db', version: 1,
          onVersionChange: (event) {
        var oldVersion = event.oldVersion;
        if (oldVersion < 1) {
          event.db.createStore(testStore);
        }
      });
      await db.inStoreTransaction(testStore, SdbTransactionMode.readWrite,
          (txn) async {
        var key = await testStore.add(txn, {'test': 1});
        expect(key, 1);
        var key2 = await testStore.add(txn, {'test': 2});
        expect(key2, 2);

        var record = (await testStore.record(key).get(txn))!;
        expect(record.value, {'test': 1});
        expect(record.key, key);
        record = (await testStore.record(key2).get(txn))!;
        expect(record.value, {'test': 2});
        expect(await testStore.record(3).get(txn), isNull);
        await testStore.record(key).delete(txn);
        expect(await testStore.record(key).get(txn), isNull);

        await testStore.record(key).put(txn, {'test': 3});
        record = (await testStore.record(key).get(txn))!;
        expect(record.value, {'test': 3});
        expect(record.key, key);
      });
      /*
     */
      await db.close();
    });
    test('boundaries int', () async {
      await factory.deleteDatabase('test_boundaries.db');
      var db = await factory.openDatabase('test_boundaries.db', version: 1,
          onVersionChange: (event) {
        var oldVersion = event.oldVersion;
        if (oldVersion < 1) {
          event.db.createStore(testStore);
        }
      });
      await db.inStoreTransaction(testStore, SdbTransactionMode.readWrite,
          (txn) async {
        await txn.add({'test': 1});
        await txn.add({'test': 2});
        await txn.add({'test': 3});
      });
      var records = await testStore.findRecords(db,
          boundaries: SdbBoundaries(SdbLowerBoundary(1), SdbUpperBoundary(3)));
      expect(records.length, 2);

      await db.close();
    });

    test('txn boundaries int', () async {
      await factory.deleteDatabase('test_boundaries.db');
      var db = await factory.openDatabase('test_boundaries.db', version: 1,
          onVersionChange: (event) {
        var oldVersion = event.oldVersion;
        if (oldVersion < 1) {
          event.db.createStore(testStore);
        }
      });
      await db.inStoreTransaction(testStore, SdbTransactionMode.readWrite,
          (txn) async {
        await txn.add({'test': 1});
        await txn.add({'test': 2});
        await txn.add({'test': 3});

        var records = await testStore.findRecords(txn,
            boundaries:
                SdbBoundaries(SdbLowerBoundary(1), SdbUpperBoundary(3)));
        expect(records.length, 2);
      });

      await db.close();
    });
  });

  group('string key', () {
    test('put/get/delete string', () async {
      await factory.deleteDatabase('test_put_get.db');
      var db = await factory.openDatabase('test_put_get.db', version: 1,
          onVersionChange: (event) {
        var oldVersion = event.oldVersion;
        if (oldVersion < 1) {
          event.db.createStore(testStore2);
        }
      });
      var key = await testStore2.add(db, {'test': 1});
      expect(key.isNotEmpty, isTrue);
      var key2 = await testStore2.add(db, {'test': 2});
      var record = (await testStore2.record(key).get(db))!;
      expect(record.value, {'test': 1});
      expect(record.key, key);
      record = (await testStore2.record(key2).get(db))!;
      expect(record.value, {'test': 2});
      expect(await testStore2.record('dummy').get(db), isNull);
      await testStore2.record(key).delete(db);
      expect(await testStore2.record(key).get(db), isNull);
      await db.close();
    });
  });

  test('multi store', () async {
    var dbName = 'test_multi_store.db';
    await factory.deleteDatabase(dbName);
    var db = await factory.openDatabase(dbName, version: 1,
        onVersionChange: (event) {
      var oldVersion = event.oldVersion;
      if (oldVersion < 1) {
        event.db.createStore(testStore);
        event.db.createStore(testStore2);
      }
    });
    await db.inStoresTransaction(
        [testStore, testStore2], SdbTransactionMode.readWrite, (txn) async {
      var key = await txn.txnStore(testStore).add({'test': 1});
      var key2 = await txn.txnStore(testStore2).add({'test': 2});
      expect(key, 1);
      expect(key2.isNotEmpty, isTrue);
    });

    await db.close();
  });
  group('index', () {
    test('basic', () async {
      var dbName = 'test_index.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(dbName, version: 1,
          onVersionChange: (event) {
        if (event.oldVersion < 1) {
          var store = event.db.createStore(testStore);
          store.createIndex(testIndex, 'field');
        }
      });
      await testStore.add(db, {'field': 1234});
      var snapshot = (await testIndex.record(1234).get(db))!;
      expect(snapshot.key, 1);
      expect(snapshot.indexKey, 1234);
      expect(snapshot.value, {'field': 1234});

      await db.close();
    });

    test('boundaries int', () async {
      await factory.deleteDatabase('test_boundaries.db');
      var db = await factory.openDatabase('test_boundaries.db', version: 1,
          onVersionChange: (event) {
        var oldVersion = event.oldVersion;
        if (oldVersion < 1) {
          var store = event.db.createStore(testStore);
          store.createIndex(testIndex, 'test');
        }
      });
      await db.inStoreTransaction(testStore, SdbTransactionMode.readWrite,
          (txn) async {
        await txn.add({'test': 1});
        await txn.add({'test': 2});
        await txn.add({'test': 3});
      });
      var records = await testIndex.findRecords(db,
          boundaries: SdbBoundaries(SdbLowerBoundary(1), SdbUpperBoundary(3)));
      expect(records.length, 2);

      await db.close();
    });
    test('schema', () async {
      var dbName = 'test_schema.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(dbName, version: 1,
          onVersionChange: (event) {
        if (event.oldVersion < 1) {
          event.db.createStore(testStore);
        }
      });
      await testStore.add(db, {'field': 1234});
      await db.close();
      db = await factory.openDatabase(dbName, version: 2,
          onVersionChange: (event) {
        if (event.oldVersion < 2) {
          var store = event.db.objectStore(testStore);
          store.createIndex(testIndex, 'field');
        }
      });
      var snapshot = (await testIndex.record(1234).get(db))!;
      expect(snapshot.key, 1);
      expect(snapshot.indexKey, 1234);
      expect(snapshot.value, {'field': 1234});

      await db.close();
    });
  });
}
