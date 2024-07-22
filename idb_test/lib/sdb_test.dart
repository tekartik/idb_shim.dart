import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:idb_shim/sdb.dart';

void main() {
  IdbFactoryLogger.debugMaxLogCount = 100;
  var idbFactory = idb.idbFactoryMemoryFs;
  idbFactory = getIdbFactoryLogger(idbFactory);

  simpleDbTest(idbFactory);
}

var testStore = SdbStoreRef<int, SdbModel>('test');
var testIndex = testStore.index<int>('myindex');
var testStore2 = SdbStoreRef<String, SdbModel>('test2');

void simpleDbTest(idb.IdbFactory idbFactory) {
  var factory = sdbFactoryFromIdb(idbFactory);
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
      SdbRecordRef<int, SdbModel> recordRef = testStore.record(key);
      SdbRecordSnapshot<int, SdbModel> record = (await recordRef.get(db))!;
      expect(record.value, {'test': 1});
      expect(record.key, key);
      expect(await testStore.record(key).getValue(db), {'test': 1});
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
      var boundaries = SdbBoundaries(SdbLowerBoundary(1), SdbUpperBoundary(3));
      var records = await testStore.findRecords(db, boundaries: boundaries);
      expect(records.length, 2);
      var keys = await testStore.findRecordKeys(db, boundaries: boundaries);
      expect(keys.keys, [1, 2]);
      var count = await testStore.count(db, boundaries: boundaries);
      expect(count, 2);

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

        var boundaries =
            SdbBoundaries(SdbLowerBoundary(1), SdbUpperBoundary(3));
        var records = await testStore.findRecords(txn, boundaries: boundaries);
        expect(records.length, 2);
        var keys = await testStore.findRecordKeys(txn, boundaries: boundaries);
        expect(keys.keys, [1, 2]);
        var count = await testStore.count(txn, boundaries: boundaries);
        expect(count, 2);
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
      SdbIndexRecordRef<int, SdbModel, int> recordRef = testIndex.record(1234);
      var snapshot = (await recordRef.get(db))!;
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

        var boundaries =
            SdbBoundaries(SdbLowerBoundary(1), SdbUpperBoundary(3));
        var records = await testIndex.findRecords(txn, boundaries: boundaries);
        expect(records.length, 2);
        var keys = await testIndex.findRecordKeys(txn, boundaries: boundaries);
        expect(keys.length, 2);
        expect(await testIndex.count(txn, boundaries: boundaries), 2);
      });
      var boundaries = SdbBoundaries(SdbLowerBoundary(1), SdbUpperBoundary(3));
      var records = await testIndex.findRecords(db, boundaries: boundaries);
      expect(records.length, 2);
      var keys = await testIndex.findRecordKeys(db, boundaries: boundaries);
      expect(keys.length, 2);
      expect(await testIndex.count(db, boundaries: boundaries), 2);

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

  group(
    'index2',
    () {
      test('index2', () async {
        var dbName = 'test_index2.db';
        await factory.deleteDatabase(dbName);

        // Our item store/table
        var itemStore = SdbStoreRef<int, SdbModel>('item');
        // Index on 'type' field
        var itemTypeIdIndex = itemStore.index2<String, int>('type_id');

        var db = await factory.openDatabase(dbName, version: 1,
            onVersionChange: (event) {
          var db = event.db;
          var oldVersion = event.oldVersion;
          if (oldVersion < 1) {
            var openStoreRef =
                db.createStore(itemStore, keyPath: 'id', autoIncrement: true);
            openStoreRef.createIndex2(itemTypeIdIndex, 'type', 'id');
          }
        });

        late int keyCatAlbert;
        late int keyCatHarriet;
        late int keyDogBeethoven;
        await db.inStoreTransaction(itemStore, SdbTransactionMode.readWrite,
            (txn) async {
          keyCatAlbert =
              await itemStore.add(txn, {'type': 'cat', 'name': 'Albert'});
          keyDogBeethoven =
              await itemStore.add(txn, {'type': 'dog', 'name': 'Beethoven'});
          keyCatHarriet =
              await itemStore.add(txn, {'type': 'cat', 'name': 'Harriet'});
        });

        var item =
            (await itemTypeIdIndex.record(('cat', keyCatHarriet)).get(db))!;
        expect(item.indexKey.$1, 'cat');
        expect(item.value['name'], 'Harriet');

        var items = await itemTypeIdIndex.findRecords(db);
        expect(items.keys, [keyCatAlbert, keyCatHarriet, keyDogBeethoven]);
        var first = items.first;
        expect(first.key, keyCatAlbert);
        expect(first.indexKey.$1, 'cat');
        expect(first.indexKey.$2, keyCatAlbert);

        items = await itemTypeIdIndex.findRecords(db,
            boundaries: SdbBoundaries(
                itemTypeIdIndex.lowerBoundary('cat', keyCatAlbert,
                    include: false),
                null));
        expect(items.keys, [keyCatHarriet, keyDogBeethoven]);

        items = await itemTypeIdIndex.findRecords(db,
            boundaries: SdbBoundaries(
              null,
              itemTypeIdIndex.upperBoundary('cat', keyCatHarriet),
            ));
        expect(items.keys, [keyCatAlbert]);

        items = await itemTypeIdIndex.findRecords(db,
            boundaries: SdbBoundaries(
              itemTypeIdIndex.lowerBoundary('cat', keyCatAlbert,
                  include: false),
              itemTypeIdIndex.upperBoundary('dog', keyDogBeethoven),
            ));
        expect(items.keys, [keyCatHarriet]);

        // Beethoven is actually a cat...
        await itemStore.put(
            db, {'id': keyDogBeethoven, 'type': 'cat', 'name': 'Beethoven'});
        // it should change the index order
        items = await itemTypeIdIndex.findRecords(db);
        expect(items.keys, [keyCatAlbert, keyDogBeethoven, keyCatHarriet]);
        // Close the database
        await db.close();
      });

      test('index3', () async {
        var dbName = 'test_index3.db';
        await factory.deleteDatabase(dbName);

        // Our item store/table
        var store = SdbStoreRef<int, SdbModel>('test');
        // Index on 'type' field
        var index = store.index3<String, int, String>('col1_col2_col3');

        var db = await factory.openDatabase(dbName, version: 1,
            onVersionChange: (event) {
          var db = event.db;
          var oldVersion = event.oldVersion;
          if (oldVersion < 1) {
            var openStoreRef =
                db.createStore(store, keyPath: 'id', autoIncrement: true);
            openStoreRef.createIndex3(index, 'col1', 'col2', 'col3');
          }
        });

        late int key1;
        late int key2;
        late int key3;
        await db.inStoreTransaction(store, SdbTransactionMode.readWrite,
            (txn) async {
          key1 = await store.add(txn, {'col1': 'a', 'col2': 1, 'col3': 'i'});
          key2 = await store.add(txn, {'col1': 'b', 'col2': 1, 'col3': 'i'});
          key3 = await store.add(txn, {'col1': 'a', 'col2': 1, 'col3': 'j'});
        });

        var item = (await index.record(('a', 1, 'i')).get(db))!;
        expect(item.indexKey, ('a', 1, 'i'));

        var items = await index.findRecords(db);
        expect(items.keys, [key1, key3, key2]);
        expect(items.indexKeys, [('a', 1, 'i'), ('a', 1, 'j'), ('b', 1, 'i')]);
        // Close the database
        await db.close();
      });

      test('index4', () async {
        var dbName = 'test_index4.db';
        await factory.deleteDatabase(dbName);

        // Our item store/table
        var store = SdbStoreRef<int, SdbModel>('test');
        // Index on 'type' field
        var index =
            store.index4<String, int, String, int>('col1_col2_col3_col4');

        var db = await factory.openDatabase(dbName, version: 1,
            onVersionChange: (event) {
          var db = event.db;
          var oldVersion = event.oldVersion;
          if (oldVersion < 1) {
            var openStoreRef =
                db.createStore(store, keyPath: 'id', autoIncrement: true);
            openStoreRef.createIndex4(index, 'col1', 'col2', 'col3', 'col4');
          }
        });

        late int key1;
        late int key2;
        late int key3;
        await db.inStoreTransaction(store, SdbTransactionMode.readWrite,
            (txn) async {
          key1 = await store
              .add(txn, {'col1': 'a', 'col2': 1, 'col3': 'i', 'col4': 2});
          key2 = await store
              .add(txn, {'col1': 'b', 'col2': 1, 'col3': 'i', 'col4': 3});
          key3 = await store
              .add(txn, {'col1': 'a', 'col2': 1, 'col3': 'j', 'col4': 4});
        });

        var item = (await index.record(('a', 1, 'i', 2)).get(db))!;
        expect(item.indexKey, ('a', 1, 'i', 2));

        var items = await index.findRecords(db);
        expect(items.keys, [key1, key3, key2]);
        expect(items.indexKeys,
            [('a', 1, 'i', 2), ('a', 1, 'j', 4), ('b', 1, 'i', 3)]);
        // Close the database
        await db.close();
      });
    },
  );
}
