library database_test;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

main() {
  defineTests_(idbMemoryContext);
}

void defineTests_(TestContext ctx) {
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

    _openWith1Store() {
      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        //ObjectStore objectStore =
        db.createObjectStore(testStoreName);
      }
      return idbFactory
          .open(_dbName, version: 1, onUpgradeNeeded: _initializeDatabase)
          .then((Database database) {
        db = database;
      });
    }

    _onBlocked(Event event) {
      //idbDevPrint("# onBlocked: $event");
    }

    _openWith1OtherStore() async {
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
      List<String> storeNames = new List.from(db.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      db.close();
      // re-open
      await _openDb();
      storeNames = new List.from(db.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames, [testStoreName]);
    });

    test('one_then_one', () async {
      await _setupDeleteDb();
      await _openWith1Store();
      List<String> storeNames = new List.from(db.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      db.close();
      // re-open
      await _openWith1OtherStore();
      storeNames = new List.from(db.objectStoreNames);
      expect(storeNames.length, 2);
      expect(storeNames, [testStoreName, testStoreName + "_2"]);
    });

    test('twice', () async {
      await _setupDeleteDb();
      await _openWith1Store();
      List<String> storeNames = new List.from(db.objectStoreNames);
      expect(storeNames.length, 1);
      expect(storeNames[0], testStoreName);

      Database db1 = db;
      // db.close();
      // re-open
      await _openWith1Store();
      storeNames = new List.from(db.objectStoreNames);
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
      List<String> storeNames = new List.from(db.objectStoreNames);
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
