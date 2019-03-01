library database_test;

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;

  group('database', () {
    Database db;

    // new
    String _dbName;
    // prepare for test
    Future _setupDeleteDb() async {
      _dbName = ctx.dbName;
      await idbFactory.deleteDatabase(_dbName);
    }

    Future _openDb() async {
      db = await idbFactory.open(_dbName);
    }

    Future _openWith1Store() async {
      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        //ObjectStore objectStore =
        db.createObjectStore(testStoreName);
      }

      db = await idbFactory.open(_dbName,
          version: 1, onUpgradeNeeded: _initializeDatabase);
    }

    void _onBlocked(Event event) {
      //idbDevPrint("# onBlocked: $event");
    }

    Future _openWith1OtherStore() async {
      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        // ObjectStore objectStore =
        db.createObjectStore(testStoreName + "_2");
      }

      db = await idbFactory.open(_dbName,
          version: 2,
          onUpgradeNeeded: _initializeDatabase,
          onBlocked: _onBlocked);
    }

    setUp(() {
      // new test - make sure _deleteDb is called
      _dbName = null;
    });

    tearDown(() {
      if (db != null) {
        db.close();
      }
    });

    test('empty', () async {
      await _setupDeleteDb();
      await _openDb();
      expect(db.factory, idbFactory);
      expect(db.objectStoreNames.isEmpty, true);
      expect(db.name, _dbName);
      expect(db.version, 1);
    });

    test('one', () async {
      await _setupDeleteDb();
      await _openWith1Store();
      List<String> storeNames = List.from(db.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      db.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        // re-open
        await _openDb();
        storeNames = List.from(db.objectStoreNames);
        expect(storeNames.length, 1);
        expect(storeNames, [testStoreName]);
      }
    });

    test('one_then_one', () async {
      await _setupDeleteDb();
      await _openWith1Store();
      List<String> storeNames = List.from(db.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      db.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        // re-open
        await _openWith1OtherStore();
        storeNames = List.from(db.objectStoreNames);
        expect(storeNames.length, 2);
        expect(storeNames, [testStoreName, testStoreName + "_2"]);
      }
    });

    test('delete_non_existing_store', () async {
      await _setupDeleteDb();

      db = await idbFactory.open(_dbName, version: 1,
          onUpgradeNeeded: (VersionChangeEvent e) {
        Database db = e.database;

        try {
          db.deleteObjectStore(testStoreName2);
          fail('should fail');
        } on DatabaseError catch (e) {
          // NotFoundError: An attempt was made to reference a Node in a context where it does not exist. The specified object store was not found.
          // NotFoundError: One of the specified object stores 'test_store_2' was not found.
          expect(isNotFoundError(e), isTrue);
        }
        db.createObjectStore(testStoreName);
      });
      db.close();
      db = await idbFactory.open(_dbName, version: 2,
          onUpgradeNeeded: (VersionChangeEvent e) {
        Database db = e.database;
        try {
          db.deleteObjectStore(testStoreName2);
          fail('should fail');
        } on DatabaseError catch (e) {
          expect(isNotFoundError(e), isTrue);
        }
      });

      db.close();
    });

    test('create_delete_index', () async {
      await _setupDeleteDb();
      db = await idbFactory.open(_dbName, version: 1,
          onUpgradeNeeded: (VersionChangeEvent e) {
        Database db = e.database;
        ObjectStore store = db.createObjectStore(testStoreName);
        store.createIndex(testNameIndex, testNameField);

        expect(store.indexNames, [testNameIndex]);
      });
      db.close();
      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        db = await idbFactory.open(_dbName, version: 2,
            onUpgradeNeeded: (VersionChangeEvent e) {
          ObjectStore store = e.transaction.objectStore(testStoreName);

          expect(store.indexNames, [testNameIndex]);
          store.deleteIndex(testNameIndex);

          expect(store.indexNames, []);
        });
        db.close();
        //await Future.delayed(Duration(milliseconds: 1));
        // check that the index is indeed gone
        db = await idbFactory.open(_dbName, version: 3,
            onUpgradeNeeded: (VersionChangeEvent e) {
          ObjectStore store = e.transaction.objectStore(testStoreName);
          expect(store.indexNames, []);
        });
        db.close();
      }
    });

    test('delete_non_existing_index', () async {
      await _setupDeleteDb();

      db = await idbFactory.open(_dbName, version: 1,
          onUpgradeNeeded: (VersionChangeEvent e) {
        Database db = e.database;
        ObjectStore store = db.createObjectStore(testStoreName);

        try {
          store.deleteIndex(testNameIndex);
          fail('should fail');
        } on DatabaseError catch (e) {
          // NotFoundError: An attempt was made to reference a Node in a context where it does not exist. The specified index was not found.
          // NotFoundError: The specified index 'name_index' was not found.
          expect(isNotFoundError(e), isTrue);
        }
      });
      db.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        db = await idbFactory.open(_dbName, version: 2,
            onUpgradeNeeded: (VersionChangeEvent e) {
          ObjectStore store = e.transaction.objectStore(testStoreName);
          try {
            store.deleteIndex(testNameIndex);
            fail('should fail');
          } on DatabaseError catch (e) {
            expect(isNotFoundError(e), isTrue);
          }
          store.createIndex(testNameIndex2, testNameField2);

          expect(store.indexNames, [testNameIndex2]);
        });
        db.close();
        db = await idbFactory.open(_dbName, version: 3,
            onUpgradeNeeded: (VersionChangeEvent e) {
          ObjectStore store = e.transaction.objectStore(testStoreName);
          store.deleteIndex(testNameIndex2);

          expect(store.indexNames, []);
        });
        db.close();
        // check that the index is indeed gone
        db = await idbFactory.open(_dbName, version: 3,
            onUpgradeNeeded: (VersionChangeEvent e) {
          ObjectStore store = e.transaction.objectStore(testStoreName);
          try {
            store.deleteIndex(testNameIndex2);
            fail('should fail');
          } on DatabaseError catch (e) {
            expect(isNotFoundError(e), isTrue);
          }
          expect(store.indexNames, []);
        });
        db.close();
      }
    });

    test('twice', () async {
      await _setupDeleteDb();
      await _openWith1Store();
      List<String> storeNames = List.from(db.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      Database db1 = db;
      // db.close();
      // re-open
      await _openWith1Store();
      storeNames = List.from(db.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      db1.close();
    });

    // does not work in IE...
    test('one keep open then one', () async {
      await _setupDeleteDb();
      await _openWith1Store();
      Database firstDb = db;

      bool db1Closed = false;

      db.onVersionChange.listen((VersionChangeEvent e) {
        //idbDevPrint("# onVersionChange");
        db.close();
        db1Closed = true;
      });

      // re-open
      await _openWith1OtherStore();
      List<String> storeNames = List.from(db.objectStoreNames);
      expect(storeNames, [testStoreName, testStoreName + "_2"]);

      // at this point native db should be close already
      if (!db1Closed) {
        Transaction transaction =
            firstDb.transaction(testStoreName, idbModeReadOnly);
        ObjectStore store = transaction.objectStore(testStoreName);
        return store.clear().then((_) {
          fail("should not succeed");
        }, onError: (e) {
          // ok
          expect(db1Closed, isTrue);
        });
      }
    }, skip: true);
  });
}
