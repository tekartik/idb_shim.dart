library database_test;

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  group('database', () {
    Database? db;

    // new
    String? dbName;
    // prepare for test
    Future setupDeleteDb() async {
      dbName = ctx.dbName;
      await idbFactory.deleteDatabase(dbName!);
    }

    Future openDb() async {
      db = await idbFactory.open(dbName!);
    }

    Future openWith1Store() async {
      void onUpgradeNeeded(VersionChangeEvent e) {
        final db = e.database;
        //ObjectStore objectStore =
        db.createObjectStore(testStoreName);
      }

      db = await idbFactory.open(dbName!,
          version: 1, onUpgradeNeeded: onUpgradeNeeded);
    }

    void openOnBlocked(Event event) {
      //idbDevPrint('# onBlocked: $event');
    }

    Future openWith1OtherStore() async {
      void onUpgradeNeeded(VersionChangeEvent e) {
        final db = e.database;
        // ObjectStore objectStore =
        db.createObjectStore('${testStoreName}_2');
      }

      db = await idbFactory.open(dbName!,
          version: 2,
          onUpgradeNeeded: onUpgradeNeeded,
          onBlocked: openOnBlocked);
    }

    setUp(() {
      // new test - make sure _deleteDb is called
      dbName = null;
    });

    tearDown(() {
      if (db != null) {
        db!.close();
      }
    });

    test('empty', () async {
      await setupDeleteDb();
      await openDb();
      expect(db!.factory, idbFactory);
      expect(db!.objectStoreNames.isEmpty, true);
      expect(db!.name, dbName);
      expect(db!.version, 1);
    });

    test('one', () async {
      await setupDeleteDb();
      void onUpgradeNeeded(VersionChangeEvent e) {
        final db = e.database;
        expect(db.objectStoreNames, <String>[]);
        final objectStore = db.createObjectStore(testStoreName);
        expect(db.objectStoreNames, [testStoreName]);
        expect(objectStore.name, testStoreName);
      }

      db = await idbFactory.open(dbName!,
          version: 1, onUpgradeNeeded: onUpgradeNeeded);
      expect(db!.objectStoreNames, [testStoreName]);

      db!.close();
    });

    test('one_then_check', () async {
      await setupDeleteDb();
      void onUpgradeNeeded(VersionChangeEvent e) {
        final db = e.database;
        expect(db.objectStoreNames, isEmpty);
        final objectStore = db.createObjectStore(testStoreName);
        expect(db.objectStoreNames, [testStoreName]);
        expect(objectStore.name, testStoreName);
      }

      db = await idbFactory.open(dbName!,
          version: 1, onUpgradeNeeded: onUpgradeNeeded);
      var storeNames = List<String>.from(db!.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      db!.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        // re-open
        await openDb();
        storeNames = List.from(db!.objectStoreNames);
        expect(storeNames.length, 1);
        expect(storeNames, [testStoreName]);
      }
    });

    test('one_then_one', () async {
      await setupDeleteDb();
      await openWith1Store();
      var storeNames = List<String>.from(db!.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      db!.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        // re-open
        await openWith1OtherStore();
        storeNames = List.from(db!.objectStoreNames);
        expect(storeNames.length, 2);
        expect(storeNames, [testStoreName, '${testStoreName}_2']);
      }
    });

    test('one_then_delete', () async {
      await setupDeleteDb();
      await openWith1Store();
      expect(db!.objectStoreNames, [testStoreName]);

      db!.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        db = await idbFactory.open(dbName!, version: 2,
            onUpgradeNeeded: (VersionChangeEvent e) {
          final db = e.database;

          expect(db.objectStoreNames, [testStoreName]);
          db.deleteObjectStore(testStoreName);
          expect(db.objectStoreNames, isEmpty);
        });

        db!.close();

        // re-open
        db = await idbFactory.open(dbName!,
            version: 2, onUpgradeNeeded: (VersionChangeEvent e) {});
        expect(db!.objectStoreNames, isEmpty);
      }
    });

    test('delete_non_existing_store', () async {
      await setupDeleteDb();

      db = await idbFactory.open(dbName!, version: 1,
          onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;

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
      db!.close();
      db = await idbFactory.open(dbName!, version: 2,
          onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        try {
          db.deleteObjectStore(testStoreName2);
          fail('should fail');
        } on DatabaseError catch (e) {
          expect(isNotFoundError(e), isTrue);
        }
      });

      db!.close();
    });

    test('create_delete_index', () async {
      await setupDeleteDb();
      db = await idbFactory.open(dbName!, version: 1,
          onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        final store = db.createObjectStore(testStoreName);
        store.createIndex(testNameIndex, testNameField);

        expect(store.indexNames, [testNameIndex]);
      });
      db!.close();
      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        db = await idbFactory.open(dbName!, version: 2,
            onUpgradeNeeded: (VersionChangeEvent e) {
          final store = e.transaction.objectStore(testStoreName);

          expect(store.indexNames, [testNameIndex]);
          store.deleteIndex(testNameIndex);

          expect(store.indexNames, isEmpty);
        });
        db!.close();
        //await Future.delayed(Duration(milliseconds: 1));
        // check that the index is indeed gone
        db = await idbFactory.open(dbName!, version: 3,
            onUpgradeNeeded: (VersionChangeEvent e) {
          final store = e.transaction.objectStore(testStoreName);
          expect(store.indexNames, isEmpty);
        });
        db!.close();
      }
    });

    test('delete_non_existing_index', () async {
      await setupDeleteDb();

      db = await idbFactory.open(dbName!, version: 1,
          onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        final store = db.createObjectStore(testStoreName);

        try {
          store.deleteIndex(testNameIndex);
          fail('should fail');
        } on DatabaseError catch (e) {
          // NotFoundError: An attempt was made to reference a Node in a context where it does not exist. The specified index was not found.
          // NotFoundError: The specified index 'name_index' was not found.
          expect(isNotFoundError(e), isTrue);
        }
      });
      db!.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        db = await idbFactory.open(dbName!, version: 2,
            onUpgradeNeeded: (VersionChangeEvent e) {
          final store = e.transaction.objectStore(testStoreName);
          try {
            store.deleteIndex(testNameIndex);
            fail('should fail');
          } on DatabaseError catch (e) {
            expect(isNotFoundError(e), isTrue);
          }
          store.createIndex(testNameIndex2, testNameField2);

          expect(store.indexNames, [testNameIndex2]);
        });
        db!.close();
        db = await idbFactory.open(dbName!, version: 3,
            onUpgradeNeeded: (VersionChangeEvent e) {
          final store = e.transaction.objectStore(testStoreName);
          store.deleteIndex(testNameIndex2);

          expect(store.indexNames, isEmpty);
        });
        db!.close();
        // check that the index is indeed gone
        db = await idbFactory.open(dbName!, version: 3,
            onUpgradeNeeded: (VersionChangeEvent e) {
          final store = e.transaction.objectStore(testStoreName);
          try {
            store.deleteIndex(testNameIndex2);
            fail('should fail');
          } on DatabaseError catch (e) {
            expect(isNotFoundError(e), isTrue);
          }
          expect(store.indexNames, isEmpty);
        });
        db!.close();
      }
    });

    test('twice', () async {
      await setupDeleteDb();
      await openWith1Store();
      var storeNames = List<String>.from(db!.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      final db1 = db!;
      // db.close();
      // re-open
      await openWith1Store();
      storeNames = List<String>.from(db!.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      db1.close();
    });

    // does not work in IE...
    test('one keep open then one', () async {
      await setupDeleteDb();
      await openWith1Store();
      final firstDb = db;

      var db1Closed = false;

      db!.onVersionChange.listen((VersionChangeEvent e) {
        //idbDevPrint('# onVersionChange');
        db!.close();
        db1Closed = true;
      });

      // re-open
      await openWith1OtherStore();
      final storeNames = List<String>.from(db!.objectStoreNames);
      expect(storeNames, [testStoreName, '${testStoreName}_2']);

      // at this point native db should be close already
      if (!db1Closed) {
        final transaction =
            firstDb!.transaction(testStoreName, idbModeReadOnly);
        final store = transaction.objectStore(testStoreName);
        return store.clear().then((_) {
          fail('should not succeed');
        }, onError: (e) {
          // ok
          expect(db1Closed, isTrue);
        });
      }
    }, skip: true);
  });
}
