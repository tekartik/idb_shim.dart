library transaction_test_common;

import 'package:unittest/unittest.dart';
import 'package:tekartik_idb/idb_client.dart';
import 'idb_test_common.dart';

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
            Transaction transaction = database.transaction(STORE_NAME, MODE_READ_WRITE);
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
        Transaction transaction = database.transaction(STORE_NAME, MODE_READ_WRITE);
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
        Transaction transaction1 = database.transaction(STORE_NAME, MODE_READ_WRITE);
        Transaction transaction2 = database.transaction(STORE_NAME, MODE_READ_WRITE);
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
//temp
    test('transactionList', () {
      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        db.createObjectStore(STORE_NAME, autoIncrement: true);
        db.createObjectStore(STORE_NAME_2, autoIncrement: true);
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        Transaction transaction = database.transactionList([STORE_NAME, STORE_NAME_2], MODE_READ_WRITE);
        //database.close();
        return transaction.completed.then((_) {
          database.close();
        });
      });
    });
  });
}
