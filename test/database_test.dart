library database_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

main() {
  defineTests(idbMemoryFactory);
}

void defineTests(IdbFactory idbFactory) {
  group('database', () {
    Database db;

    _open() {
      return idbFactory.open(testDbName).then((Database database) {
        db = database;
      });
    }

    _openWith1Store() {
      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        //ObjectStore objectStore =
        db.createObjectStore(testStoreName);
      }
      return idbFactory
          .open(testDbName, version: 1, onUpgradeNeeded: _initializeDatabase)
          .then((Database database) {
        db = database;
      });
    }

    _onBlocked(Event event) {
      //idbDevPrint("# onBlocked: $event");
    }

    _openWith1OtherStore() {
      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        // ObjectStore objectStore =
        db.createObjectStore(testStoreName + "_2");
      }
      return idbFactory
          .open(testDbName,
              version: 2,
              onUpgradeNeeded: _initializeDatabase,
              onBlocked: _onBlocked)
          .then((Database database) {
        db = database;
      });
    }

    setUp(() {
      return idbFactory.deleteDatabase(testDbName);
    });

    tearDown(() {
      if (db != null) {
        db.close();
      }
    });

    test('empty', () {
      return _open().then((_) {
        expect(db.factory, idbFactory);
        expect(db.objectStoreNames.isEmpty, true);
        expect(db.name, testDbName);
        expect(db.version, 1);
      });
    });

    test('one', () {
      return _openWith1Store().then((_) {
        List<String> storeNames = new List.from(db.objectStoreNames);
        expect(storeNames.length, 1);
        expect(storeNames[0], testStoreName);

        db.close();
        // re-open
        return _open().then((_) {
          storeNames = new List.from(db.objectStoreNames);
          expect(storeNames.length, 1);
          expect(storeNames, [testStoreName]);
        });
      });
    });

    test('one then one', () {
      return _openWith1Store().then((_) {
        List<String> storeNames = new List.from(db.objectStoreNames);
        expect(storeNames.length, 1);
        expect(storeNames[0], testStoreName);

        db.close();
        // re-open
        return _openWith1OtherStore().then((_) {
          storeNames = new List.from(db.objectStoreNames);
          expect(storeNames.length, 2);
          expect(storeNames, [testStoreName, testStoreName + "_2"]);
        });
      });
    });

    test('twice', () {
      return _openWith1Store().then((_) {
        List<String> storeNames = new List.from(db.objectStoreNames);
        expect(storeNames.length, 1);
        expect(storeNames[0], testStoreName);

        Database db1 = db;
        // db.close();
        // re-open
        return _openWith1Store().then((_) {
          storeNames = new List.from(db.objectStoreNames);
          expect(storeNames.length, 1);
          expect(storeNames[0], testStoreName);

          db1.close();
        });
      });
    });

    // does not work in IE...
    tk_skip_test('one keep open then one', () {
      return _openWith1Store().then((_) {
        Database firstDb = db;

        bool db1Closed = false;

        db.onVersionChange.listen((VersionChangeEvent e) {
          //idbDevPrint("# onVersionChange");
          db.close();
          db1Closed = true;
        });

        // re-open
        return _openWith1OtherStore().then((_) {}).then((_) {
          List<String> storeNames = new List.from(db.objectStoreNames);
          expect(storeNames, [testStoreName, testStoreName + "_2"]);
        }).then((_) {
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
        });
      });
    });
  });
}
