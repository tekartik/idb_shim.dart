library transaction_test_common;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';

// so that this can be run directly
//void _main() {
//  testMain(new IdbMemoryFactory());
//}

void testMain(IdbFactory idbFactory) {

  group('transaction', () {

    group('scratch', () {
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
      test('multiple transaction', () {
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

    group('simple', () {

      group('transaction auto', () {

        Database db;
        Transaction transaction;
        ObjectStore objectStore;

        setUp(() {
          return idbFactory.deleteDatabase(DB_NAME).then((_) {
            void _initializeDatabase(VersionChangeEvent e) {
              Database db = e.database;
              ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
            }
            return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
              db = database;
              transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
              objectStore = transaction.objectStore(STORE_NAME);
              return db;

            });
          });
        });

        tearDown(() {
          db.close();
        });

        test('immediate completed', () {

          bool done = false;
          Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
          return transaction.completed;

        });

        // not working in memory
        skip_test('add immediate completed', () {

          bool done = false;
          Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
          ObjectStore objectStore = transaction.objectStore(STORE_NAME);
          objectStore.add("value1").then((key1) {
            done = true;
          });
          return transaction.completed.then((_) {
            print('completed');
            expect(done, isTrue);
            //db.close();
            // done();
          });

        });

        // not working in memory
        skip_test('immediate completed then add', () {

          bool done = false;
          Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
          ObjectStore objectStore = transaction.objectStore(STORE_NAME);

          var completed = transaction.completed.then((_) {
            print('completed');
            expect(done, isTrue);
            //db.close();
            // done();
          });
          objectStore.add("value1").then((key1) {
            done = true;
          });
          return completed;

        });

      });
    });
    
    group('auto', () {

         Database db;

         setUp(() {
           return setUpSimpleStore(idbFactory).then((Database database) {
             db = database;
           });
         });

         tearDown(() {
           db.close();
         });

         test('immediate completed', () {

           bool done = false;
           Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           return transaction.completed;

         });

         test('add immediate completed', () {

           bool done = false;
           Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           ObjectStore objectStore = transaction.objectStore(STORE_NAME);
           objectStore.add("value1").then((key1) {
             done = true;
           });
           return transaction.completed.then((_) {
             print('completed');
             expect(done, isTrue);
             //db.close();
             // done();
           });

         });

         test('add 1 then 1 immediate completed', () {

           bool done = false;
           Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           ObjectStore objectStore = transaction.objectStore(STORE_NAME);
           objectStore.add("value1").then((key1) {
             objectStore.add("value1").then((key1) {
               done = true;
             });
           });
           return transaction.completed.then((_) {
             print('completed');
             expect(done, isTrue);
             //db.close();
             // done();
           });

         });

         test('add 1 then 1 then 1 immediate completed', () {

           bool done = false;
           Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           ObjectStore objectStore = transaction.objectStore(STORE_NAME);
           objectStore.add("value1").then((key1) {
             objectStore.add("value1").then((key1) {
               objectStore.add("value1").then((key1) {
                 done = true;
               });
             });
           });
           return transaction.completed.then((_) {
             print('completed');
             expect(done, isTrue);
             //db.close();
             // done();
           });

         });

         test('add 1 level 5 deep immediate completed', () {

           bool done = false;
           Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           ObjectStore objectStore = transaction.objectStore(STORE_NAME);
           objectStore.add("value1").then((key1) {
             objectStore.add("value1").then((key1) {
               objectStore.add("value1").then((key1) {
                 objectStore.add("value1").then((key1) {
                   objectStore.add("value1").then((key1) {
                     done = true;
                   });
                 });
               });
             });
           });
           return transaction.completed.then((_) {
             print('completed');
             expect(done, isTrue);
             //db.close();
             // done();
           });

         });

         test('immediate completed then add', () {

           bool done = false;
           Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           ObjectStore objectStore = transaction.objectStore(STORE_NAME);

           var completed = transaction.completed.then((_) {
             print('completed');
             expect(done, isTrue);
             //db.close();
             // done();
           });
           objectStore.add("value1").then((key1) {
             done = true;
           });
           return completed;

         });

         test('add 2 immediate completed', () {

           bool done1 = false;
           bool done2 = false;
           Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           ObjectStore objectStore = transaction.objectStore(STORE_NAME);
           objectStore.add("value1").then((key1) {
             expect(done1, isFalse);
             done1 = true;
           });
           objectStore.add("value2").then((key2) {
             expect(done2, isFalse);
             done2 = true;
           });
           return transaction.completed.then((_) {
             print('completed');
             expect(done1 && done2, isTrue);
             //db.close();
             // done();
           });

         });

         test('add/put immediate completed', () {

           bool done = false;
           Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           ObjectStore objectStore = transaction.objectStore(STORE_NAME);
           objectStore.add("value1").then((key1) {
             objectStore.put("value1", key1).then((key2) {
               done = true;
             });
           });
           return transaction.completed.then((_) {
             print('completed');
             expect(done, isTrue);
             //db.close();
             // done();
           });

         });

         test('add/put/get/delete', () {

           bool done = false;
           Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           ObjectStore objectStore = transaction.objectStore(STORE_NAME);
           objectStore.add("value1").then((key1) {
             expect(key1, equals(1));

             objectStore.getObject(key1).then((String value) {
               expect(value, "value1");
               objectStore.put("value2", key1).then((key2) {
                 done = true;
                 expect(key1, key2);
                 objectStore.delete(key1).then((nullValue) {
                   expect(nullValue, isNull);
                   done = true;
                 });
               });
             });
           });
           return transaction.completed.then((_) {
             print('completed');
             expect(done, isTrue);
             //db.close();
             // done();
           });

         });

         test('2 embedded transaction empty', () {

           bool done = false;
           Transaction transaction1 = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           Transaction transaction2 = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           return Future.wait([transaction1.completed, transaction2.completed]);
         });

         test('2 embedded transaction 2 put', () {

           bool done = false;
           Transaction transaction1 = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           Transaction transaction2 = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
           transaction1.objectStore(STORE_NAME).put("test").then((key) {
             expect(key, 1);
           });
           transaction2.objectStore(STORE_NAME).put("test").then((key) {
             expect(key, 2);
           });
           return Future.wait([transaction1.completed, transaction2.completed]);
         });


       });

  });
}
