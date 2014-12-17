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
      return idbFactory.open(DB_NAME).then((Database database) {
        db = database;
      });
    }

    _openWith1Store() {
      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        ObjectStore objectStore = db.createObjectStore(STORE_NAME);
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        db = database;
      });
    }

    _onBlocked(Event event) {
      //idbDevPrint("# onBlocked: $event");
    }

    _openWith1OtherStore() {
      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        ObjectStore objectStore = db.createObjectStore(STORE_NAME + "_2");
      }
      return idbFactory.open(DB_NAME, version: 2, onUpgradeNeeded: _initializeDatabase, onBlocked: _onBlocked).then((Database database) {
        db = database;
      });
    }

    setUp(() {
      return idbFactory.deleteDatabase(DB_NAME);
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
        expect(db.name, DB_NAME);
        expect(db.version, 1);
      });
    });

    test('one', () {
      return _openWith1Store().then((_) {
        List<String> storeNames = new List.from(db.objectStoreNames);
        expect(storeNames.length, 1);
        expect(storeNames[0], STORE_NAME);

        db.close();
        // re-open
        return _open().then((_) {
          storeNames = new List.from(db.objectStoreNames);
          expect(storeNames.length, 1);
          expect(storeNames, [STORE_NAME]);
        });
      });
    });

    test('one then one', () {
      return _openWith1Store().then((_) {
        List<String> storeNames = new List.from(db.objectStoreNames);
        expect(storeNames.length, 1);
        expect(storeNames[0], STORE_NAME);

        db.close();
        // re-open
        return _openWith1OtherStore().then((_) {
          storeNames = new List.from(db.objectStoreNames);
          expect(storeNames.length, 2);
          expect(storeNames, [STORE_NAME, STORE_NAME + "_2"]);
        });
      });
    });

    test('twice', () {
      return _openWith1Store().then((_) {
        List<String> storeNames = new List.from(db.objectStoreNames);
        expect(storeNames.length, 1);
        expect(storeNames[0], STORE_NAME);

        Database db1 = db;
        // db.close();
        // re-open
        return _openWith1Store().then((_) {
          storeNames = new List.from(db.objectStoreNames);
          expect(storeNames.length, 1);
          expect(storeNames[0], STORE_NAME);

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
        return _openWith1OtherStore().then((_) {

        }).then((_) {
          List<String> storeNames = new List.from(db.objectStoreNames);
          expect(storeNames, [STORE_NAME, STORE_NAME + "_2"]);
        }).then((_) {
          // at this point native db should be close already
          if (!db1Closed) {
            Transaction transaction = firstDb.transaction(STORE_NAME, IDB_MODE_READ_ONLY);
            ObjectStore store = transaction.objectStore(STORE_NAME);
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
