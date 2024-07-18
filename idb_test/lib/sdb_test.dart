import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:idb_shim/sdb/sdb.dart';

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

  group('index2', () {
    test('index2', () async {
      var dbName = 'test_index2.db';
      await factory.deleteDatabase(dbName);

      // Our pet store/table
      var petStore = SdbStoreRef<int, SdbModel>('pet');
      // Index on 'type' field
      var petTypeIdIndex = petStore.index2<String, int>('type_id');

      var db = await factory.openDatabase(dbName, version: 1,
          onVersionChange: (event) {
        var db = event.db;
        var oldVersion = event.oldVersion;
        if (oldVersion < 1) {
          var openStoreRef =
              db.createStore(petStore, keyPath: 'id', autoIncrement: true);
          openStoreRef.createIndex2(petTypeIdIndex, 'type', 'id');
        }
      });

      late int keyCatAlbert;
      late int keyCatHarriet;
      late int keyDogBeethoven;
      await db.inStoreTransaction(petStore, SdbTransactionMode.readWrite,
          (txn) async {
        keyCatAlbert =
            await petStore.add(txn, {'type': 'cat', 'name': 'Albert'});
        keyDogBeethoven =
            await petStore.add(txn, {'type': 'dog', 'name': 'Beethoven'});
        keyCatHarriet =
            await petStore.add(txn, {'type': 'cat', 'name': 'Harriet'});
      });

      var pet = (await petTypeIdIndex.record(('cat', keyCatHarriet)).get(db))!;
      expect(pet.indexKey.$1, 'cat');
      expect(pet.value['name'], 'Harriet');

      var pets = await petTypeIdIndex.findRecords(db);
      expect(pets.keys, [keyCatAlbert, keyCatHarriet, keyDogBeethoven]);
      var first = pets.first;
      expect(first.key, keyCatAlbert);
      expect(first.indexKey.$1, 'cat');
      expect(first.indexKey.$2, keyCatAlbert);

      // TODO
      // ignore: dead_code
      if (false) {
        var anyDogBoundary =
            petTypeIdIndex.lowerBoundary('dog', null, include: false);
        pets = await petTypeIdIndex.findRecords(db,
            boundaries: SdbBoundaries.lower(anyDogBoundary));
        expect(pets.keys, [keyDogBeethoven]);
      }
      // Close the database
      await db.close();
    });

    test('index3', () async {
      var dbName = 'test_index3.db';
      await factory.deleteDatabase(dbName);

      // Our pet store/table
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

      var pet = (await index.record(('a', 1, 'i')).get(db))!;
      expect(pet.indexKey, ('a', 1, 'i'));

      var pets = await index.findRecords(db);
      expect(pets.keys, [key1, key3, key2]);
      expect(pets.indexKeys, [('a', 1, 'i'), ('a', 1, 'j'), ('b', 1, 'i')]);
      // Close the database
      await db.close();
    });

    test('index4', () async {
      var dbName = 'test_index4.db';
      await factory.deleteDatabase(dbName);

      // Our pet store/table
      var store = SdbStoreRef<int, SdbModel>('test');
      // Index on 'type' field
      var index = store.index4<String, int, String, int>('col1_col2_col3_col4');

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

      var pet = (await index.record(('a', 1, 'i', 2)).get(db))!;
      expect(pet.indexKey, ('a', 1, 'i', 2));

      var pets = await index.findRecords(db);
      expect(pets.keys, [key1, key3, key2]);
      expect(pets.indexKeys,
          [('a', 1, 'i', 2), ('a', 1, 'j', 4), ('b', 1, 'i', 3)]);
      // Close the database
      await db.close();
    });
  });
}
