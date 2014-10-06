library transaction_test_common;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  testMain(new IdbMemoryFactory());
}

void testMain(IdbFactory idbFactory) {

  group('transaction', () {

    setUp(() {
      return idbFactory.deleteDatabase(DB_NAME);
    });

    test('put & completed', () {
      Database db;
      void _initializeDatabase(VersionChangeEvent e) {
        db = e.database;
        ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        Transaction transaction = database.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
        ObjectStore objectStore = transaction.objectStore(STORE_NAME);
        bool putDone = false;
        objectStore.put(1).then((_) {
          putDone = true;
        });
        return transaction.completed.then((Database db) {
          expect(putDone, isTrue);
        });
      }).then((_) {
        db.close();
      });




    });

    test('empty transaction', () {
      Database db;
      void _initializeDatabase(VersionChangeEvent e) {
        db = e.database;
        ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        Transaction transaction = database.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
        return transaction.completed;
      }).then((Database db) {
        db.close();
      });




    });
    skip_test('multiple transaction', () {
      Database db;
      void _initializeDatabase(VersionChangeEvent e) {
        db = e.database;
        ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        Transaction transaction1 = database.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
        Transaction transaction2 = database.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
        bool transaction1Completed = false;
        ObjectStore objectStore1 = transaction1.objectStore(STORE_NAME);
        objectStore1.clear().then((_) {
          objectStore1.clear().then((_) {
            transaction1Completed = true;
          });
        });
        ObjectStore objectStore2 = transaction2.objectStore(STORE_NAME);
        return objectStore2.clear().then((_) {
          expect(transaction1Completed, isTrue);
          return transaction2.completed.then((_) {
            database.close();
          });
        });

      });

    });

    test('chain 2 transactions', () {
      Database db;
      void _initializeDatabase(VersionChangeEvent e) {
        db = e.database;
        ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        Transaction transaction = database.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
        ObjectStore objectStore = transaction.objectStore(STORE_NAME);
        return objectStore.put({}).then((_) {
          Transaction transaction = database.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
          ObjectStore objectStore = transaction.objectStore(STORE_NAME);
          return objectStore.openCursor(autoAdvance: true).listen((cursor) {
            print(cursor);
          }).asFuture().then((_) {
            return transaction.completed.then((_) {
              database.close();
            });
          });
        });
      });

    });
    //temp
    test('transactionList', () {
      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        db.createObjectStore(STORE_NAME, autoIncrement: true);
        db.createObjectStore(STORE_NAME_2, autoIncrement: true);
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        Transaction transaction = database.transactionList([STORE_NAME, STORE_NAME_2], IDB_MODE_READ_WRITE);
        //database.close();
        return transaction.completed.then((_) {
          database.close();
        });
      });
    });

    test('bad_mode', () {

      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        db.createObjectStore(STORE_NAME, autoIncrement: true);
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        Transaction transaction = database.transaction(STORE_NAME, IDB_MODE_READ_ONLY);

        ObjectStore store = transaction.objectStore(STORE_NAME);

        store.put({}).catchError((e) {
          // There must be an error!
          //print(e);
          //print(e.runtimeType);
          return e;
        }).then((e) {
          // there must be an error
          expect(isTransactionReadOnlyError(e), isTrue);
        }).then((_) {

        });
        //database.close();
        return transaction.completed.then((_) {
          database.close();
        });
      });
    });

    test('bad_store', () {

      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        db.createObjectStore(STORE_NAME, autoIncrement: true);
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        try {
          Transaction transaction = database.transaction(STORE_NAME_2, IDB_MODE_READ_WRITE);
          fail("exception expected");
        } catch (e) {
          //print(e);
          //print(e.runtimeType);
          expect(isStoreNotFoundError(e), isTrue);
        }

        database.close();

      });
    });
  });
}
