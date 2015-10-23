library transaction_test_common;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';

// so that this can be run directly
main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;
  group('transaction', () {
    group('scratch', () {
      setUp(() {
        return idbFactory.deleteDatabase(testDbName);
      });

      test('put & completed', () {
        Database db;
        void _initializeDatabase(VersionChangeEvent e) {
          db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        return idbFactory
            .open(testDbName, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          Transaction transaction =
              database.transaction(testStoreName, idbModeReadWrite);
          ObjectStore objectStore = transaction.objectStore(testStoreName);
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
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        return idbFactory
            .open(testDbName, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          Transaction transaction =
              database.transaction(testStoreName, idbModeReadWrite);
          return transaction.completed;
        }).then((Database db) {
          db.close();
        });
      });
      test('multiple transaction', () {
        Database db;
        void _initializeDatabase(VersionChangeEvent e) {
          db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        return idbFactory
            .open(testDbName, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          Transaction transaction1 =
              database.transaction(testStoreName, idbModeReadWrite);
          Transaction transaction2 =
              database.transaction(testStoreName, idbModeReadWrite);
          bool transaction1Completed = false;
          ObjectStore objectStore1 = transaction1.objectStore(testStoreName);
          objectStore1.clear().then((_) {
            objectStore1.clear().then((_) {
              transaction1Completed = true;
            });
          });
          ObjectStore objectStore2 = transaction2.objectStore(testStoreName);
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
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        return idbFactory
            .open(testDbName, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          Transaction transaction =
              database.transaction(testStoreName, idbModeReadWrite);
          ObjectStore objectStore = transaction.objectStore(testStoreName);
          return objectStore.put({}).then((_) {
            Transaction transaction =
                database.transaction(testStoreName, idbModeReadWrite);
            ObjectStore objectStore = transaction.objectStore(testStoreName);
            return objectStore.openCursor(autoAdvance: true).listen((cursor) {
              //print(cursor);
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
          db.createObjectStore(testStoreName, autoIncrement: true);
          db.createObjectStore(testStoreName2, autoIncrement: true);
        }
        return idbFactory
            .open(testDbName, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          Transaction transaction = database.transactionList(
              [testStoreName, testStoreName2], idbModeReadWrite);
          //database.close();
          return transaction.completed.then((_) {
            database.close();
          });
        });
      });

      test('bad_mode', () {
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        return idbFactory
            .open(testDbName, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          Transaction transaction =
              database.transaction(testStoreName, idbModeReadOnly);

          ObjectStore store = transaction.objectStore(testStoreName);

          store.put({}).catchError((e) {
            // There must be an error!
            //print(e);
            //print(e.runtimeType);
            return e;
          }).then((e) {
            // there must be an error
            expect(isTransactionReadOnlyError(e), isTrue);
          }).then((_) {});
          //database.close();
          return transaction.completed.then((_) {
            database.close();
          });
        });
      });

      test('bad_store_transaction', () {
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        return idbFactory
            .open(testDbName, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          try {
            database.transaction(testStoreName2, idbModeReadWrite);
            fail("exception expected");
          } catch (e) {
            //print(e);
            //print(e.runtimeType);
            expect(isStoreNotFoundError(e), isTrue);
          }

          database.close();
        });
      });

      test('bad_store', () {
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        return idbFactory
            .open(testDbName, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          Transaction transaction =
              database.transaction(testStoreName, idbModeReadWrite);
          try {
            transaction.objectStore(testStoreName2);
            fail("exception expected");
          } catch (e) {
            // NotFoundError: An attempt was made to reference a Node in a context where it does not exist. The specified object store was not found.
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
        //ObjectStore objectStore;

        setUp(() {
          return idbFactory.deleteDatabase(testDbName).then((_) {
            void _initializeDatabase(VersionChangeEvent e) {
              Database db = e.database;
              db.createObjectStore(testStoreName, autoIncrement: true);
            }
            return idbFactory
                .open(testDbName,
                    version: 1, onUpgradeNeeded: _initializeDatabase)
                .then((Database database) {
              db = database;
              transaction = db.transaction(testStoreName, idbModeReadWrite);
              transaction.objectStore(testStoreName);
              return db;
            });
          });
        });

        tearDown(() {
          db.close();
        });

        test('immediate completed', () {
          //bool done = false;
          Transaction transaction =
              db.transaction(testStoreName, idbModeReadWrite);
          return transaction.completed;
        });

        test('add immediate completed', () {
          // not working in memory
          // devPrint("***** ${idbFactory.name}");
          if (idbFactory.name != idbFactoryWebSql) {
            bool done = false;
            Transaction transaction =
                db.transaction(testStoreName, idbModeReadWrite);
            ObjectStore objectStore = transaction.objectStore(testStoreName);
            objectStore.add("value1").then((key1) {
              done = true;
            });
            return transaction.completed.then((_) {
              expect(done, isTrue);
              //db.close();
              // done();
            });
          }
        });

        // not working in memory
        test('immediate completed then add', () {
// not working in memory
          // devPrint("***** ${idbFactory.name}");
          if (idbFactory.name != idbFactoryWebSql) {
            bool done = false;
            Transaction transaction =
                db.transaction(testStoreName, idbModeReadWrite);
            ObjectStore objectStore = transaction.objectStore(testStoreName);

            var completed = transaction.completed.then((_) {
              expect(done, isTrue);
              //db.close();
              // done();
            });
            objectStore.add("value1").then((key1) {
              done = true;
            });
            return completed;
          }
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
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        return transaction.completed;
      });

      test('add immediate completed', () {
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        objectStore.add("value1").then((key1) {
          done = true;
        });
        return transaction.completed.then((_) {
          expect(done, isTrue);
          //db.close();
          // done();
        });
      });

      test('add 1 then 1 immediate completed', () {
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        objectStore.add("value1").then((key1) {
          objectStore.add("value1").then((key1) {
            done = true;
          });
        });
        return transaction.completed.then((_) {
          expect(done, isTrue);
          //db.close();
          // done();
        });
      });

      // The following tests when there are extra await in the transaction

      test('get_get', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);
        await objectStore.getObject(0);
        await transaction.completed;
      });

      test('get_wait_get', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);
        await new Future.value();
        await objectStore.getObject(0);
        await transaction.completed;
      });

      test('get_wait_wait_get', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);
        await new Future.value();
        await new Future.value();
        await objectStore.getObject(0);
        await transaction.completed;
      });

      test('put_wait_wait_put', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.put({});
        await new Future.value();
        await new Future.value();
        await objectStore.put({});
        await transaction.completed;
      });

      test('add 1 then 1 then 1 immediate completed', () {
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        objectStore.add("value1").then((key1) {
          objectStore.add("value1").then((key1) {
            objectStore.add("value1").then((key1) {
              done = true;
            });
          });
        });
        return transaction.completed.then((_) {
          expect(done, isTrue);
          //db.close();
          // done();
        });
      });

      test('add 1 level 5 deep immediate completed', () {
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
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
          expect(done, isTrue);
          //db.close();
          // done();
        });
      });

      test('immediate completed then add', () {
        if ((idbFactory.name != idbFactoryWebSql)) {
          bool done = false;
          Transaction transaction =
              db.transaction(testStoreName, idbModeReadWrite);
          ObjectStore objectStore = transaction.objectStore(testStoreName);

          var completed = transaction.completed.then((_) {
            expect(done, isTrue);
            //db.close();
            // done();
          });
          objectStore.add("value1").then((key1) {
            done = true;
          });
          return completed;
        }
      });

      test('add 2 immediate completed', () {
        bool done1 = false;
        bool done2 = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        objectStore.add("value1").then((key1) {
          expect(done1, isFalse);
          done1 = true;
        });
        objectStore.add("value2").then((key2) {
          expect(done2, isFalse);
          done2 = true;
        });
        return transaction.completed.then((_) {
          expect(done1 && done2, isTrue);
          //db.close();
          // done();
        });
      });

      test('add/put immediate completed', () {
        if ((idbFactory.name != idbFactoryWebSql)) {
          bool done = false;
          Transaction transaction =
              db.transaction(testStoreName, idbModeReadWrite);
          ObjectStore objectStore = transaction.objectStore(testStoreName);
          objectStore.add("value1").then((key1) {
            objectStore.put("value1", key1).then((key2) {
              done = true;
            });
          });
          return transaction.completed.then((_) {
            expect(done, isTrue);
            //db.close();
            // done();
          });
        }
      });

      test('add/put/get/delete', () {
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
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
          expect(done, isTrue);
          //db.close();
          // done();
        });
      });

      test('2 embedded transaction empty', () {
        Transaction transaction1 =
            db.transaction(testStoreName, idbModeReadWrite);
        Transaction transaction2 =
            db.transaction(testStoreName, idbModeReadWrite);
        return Future.wait([transaction1.completed, transaction2.completed]);
      });

      test('2 embedded transaction 2 put', () {
        Transaction transaction1 =
            db.transaction(testStoreName, idbModeReadWrite);
        Transaction transaction2 =
            db.transaction(testStoreName, idbModeReadWrite);
        transaction1.objectStore(testStoreName).put("test").then((key) {
          expect(key, 1);
        });
        transaction2.objectStore(testStoreName).put("test").then((key) {
          expect(key, 2);
        });
        return Future.wait([transaction1.completed, transaction2.completed]);
      });
    });
  });
}
