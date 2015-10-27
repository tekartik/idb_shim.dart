library idb_shim.utils_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/utils/idb_utils.dart';
import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;

  Database db;
  Database dstDb;
  String _srcDbName;
  String _dstDbName;
  // prepare for test
  Future _setupDeleteDb() async {
    _srcDbName = ctx.dbName;
    _dstDbName = "dst_${_srcDbName}";
    await idbFactory.deleteDatabase(_srcDbName);
  }

  _tearDown() {
    if (db != null) {
      db.close();
      db = null;
    }
    if (dstDb != null) {
      dstDb.close();
      dstDb = null;
    }
  }

  group('utils', () {
    group('copySchema', () {
      tearDown(_tearDown);
      test('empty', () async {
        await _setupDeleteDb();
        db = await idbFactory.open(_srcDbName);
        dstDb = await copySchema(db, idbFactory, _dstDbName);
        expect(dstDb.factory, idbFactory);
        expect(dstDb.objectStoreNames.isEmpty, true);
        expect(dstDb.name, _dstDbName);
        expect(dstDb.version, 1);
      });

      test('one_store', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName,
              keyPath: testNameField, autoIncrement: true);
        }
        db = await idbFactory.open(_srcDbName,
            version: 2, onUpgradeNeeded: _initializeDatabase);

        dstDb = await copySchema(db, idbFactory, _dstDbName);
        expect(dstDb.factory, idbFactory);
        expect(dstDb.objectStoreNames, [testStoreName]);
        expect(dstDb.name, _dstDbName);
        expect(dstDb.version, 2);
        Transaction txn = dstDb.transaction(testStoreName, idbModeReadOnly);
        ObjectStore store = txn.objectStore(testStoreName);
        expect(store.name, testStoreName);
        expect(store.keyPath, testNameField);
        expect(store.autoIncrement, isTrue);
        expect(store.indexNames, []);
        await txn.completed;
      });

      test('one_index', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              unique: true, multiEntry: true);
        }
        db = await idbFactory.open(_srcDbName,
            version: 3, onUpgradeNeeded: _initializeDatabase);

        dstDb = await copySchema(db, idbFactory, _dstDbName);
        expect(dstDb.version, 3);
        Transaction txn = dstDb.transaction(testStoreName, idbModeReadOnly);
        ObjectStore store = txn.objectStore(testStoreName);
        expect(store.indexNames, [testNameIndex]);
        Index index = store.index(testNameIndex);
        expect(index.name, testNameIndex);
        expect(index.keyPath, testNameField);
        expect(index.unique, isTrue);
        expect(index.multiEntry, isTrue);
        await txn.completed;
      });
    });

    group('copyStore', () {
      tearDown(_tearDown);

      test('empty', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(_srcDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        await copyStore(db, testStoreName, db, testStoreName2);

        Transaction txn = db.transaction(testStoreName2, idbModeReadOnly);
        ObjectStore store = txn.objectStore(testStoreName2);
        expect(await store.count(), 0);
        await txn.completed;
      });

      test('one_record', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(_srcDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        // put one in src and one in dst that should get deleted
        Transaction txn =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        ObjectStore store = txn.objectStore(testStoreName);
        await (store.put("value1", "key1"));
        ObjectStore store2 = txn.objectStore(testStoreName2);
        await (store2.put("value2", "key2"));
        await txn.completed;

        await copyStore(db, testStoreName, db, testStoreName2);

        txn = db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
        store = txn.objectStore(testStoreName);
        expect(await store.getObject("key1"), "value1");
        expect(await store.count(), 1);
        store2 = txn.objectStore(testStoreName2);
        expect(await store2.getObject("key1"), "value1");
        expect(await store2.count(), 1);
        await txn.completed;
      });
    });

    group('copyDatabase', () {
      tearDown(_tearDown);
      test('empty', () async {
        await _setupDeleteDb();
        db = await idbFactory.open(_srcDbName);
        dstDb = await copyDatabase(db, idbFactory, _dstDbName);
        expect(dstDb.factory, idbFactory);
        expect(dstDb.objectStoreNames.isEmpty, true);
        expect(dstDb.name, _dstDbName);
        expect(dstDb.version, 1);
      });

      test('two_store_two_records', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(_srcDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        // put one in src and one in dst that should get deleted
        Transaction txn = db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore store = txn.objectStore(testStoreName);
        await (store.put("value1", "key1"));
        await (store.put("value2", "key2"));
        await txn.completed;

        dstDb = await copyDatabase(db, idbFactory, _dstDbName);

        txn =
            dstDb.transaction([testStoreName, testStoreName2], idbModeReadOnly);
        store = txn.objectStore(testStoreName);
        expect(await store.getObject("key1"), "value1");
        expect(await store.getObject("key2"), "value2");
        expect(await store.count(), 2);
        ObjectStore store2 = txn.objectStore(testStoreName2);
        expect(await store2.count(), 0);
        await txn.completed;
      });
    });
  });
}
