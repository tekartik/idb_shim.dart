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
    // new
    Database db;
    String _dbName;
    // prepare for test
    Future _setupDeleteDb() async {
      _dbName = ctx.dbName;
      await idbFactory.deleteDatabase(_dbName);
    }
    Future _tearDown() async {
      if (db != null) {
        db.close();
        db = null;
      }
    }
    //String testDbName = ctx.dbName;
    group('scratch', () {
      setUp(() {
        return idbFactory.deleteDatabase(testDbName);
      });

      tearDown(_tearDown);

      test('put & completed', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        db = await idbFactory.open(testDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        bool putDone = false;
        objectStore.put(1).then((_) {
          putDone = true;
        });
        await transaction.completed;
        expect(putDone, isTrue);
      });

      test('empty transaction', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        db = await idbFactory.open(testDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        await transaction.completed;
      });
      test('multiple transaction', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          e.database.createObjectStore(testStoreName, autoIncrement: true);
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

      test('chain 2 transactions', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          e.database.createObjectStore(testStoreName, autoIncrement: true);
        }
        db = await idbFactory.open(testDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.put({});
        Transaction transaction2 =
            db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction2.objectStore(testStoreName);
        await objectStore.openCursor(autoAdvance: true).listen((cursor) {
          //print(cursor);
        }).asFuture();
        await transaction2.completed;
        // BUG in indexeddb native - this never complete await transaction.completed;
      });

      test('transactionList', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
          db.createObjectStore(testStoreName2, autoIncrement: false);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        // not supported on safari!
        try {
          Transaction transaction = db.transactionList(
              [testStoreName, testStoreName2], idbModeReadWrite);
          if (ctx.isIdbSafari) {
            fail("currently fails...");
          }
          await transaction.completed;
        } on DatabaseError catch (e) {
          if (!ctx.isIdbSafari) {
            rethrow;
          }
          expect(isNotFoundError(e), isTrue);
        }
      });

      test('bad_mode', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);

        ObjectStore store = transaction.objectStore(testStoreName);

        await store.put({}).catchError((e) {
          // There must be an error!
          //print(e);
          //print(e.runtimeType);
          return e;
        }).then((e) {
          // there must be an error
          expect(isTransactionReadOnlyError(e), isTrue);
        });
        //database.close();
        await transaction.completed;
      });

      test('bad_store_transaction', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        try {
          db.transaction(testStoreName2, idbModeReadWrite);
          fail("exception expected");
        } catch (e) {
          //print(e);
          //print(e.runtimeType);
          expect(isNotFoundError(e), isTrue);
        }
      });

      test('no_store_transaction_list', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        try {
          db.transactionList([], idbModeReadWrite);
          fail("exception expected");
        } on DatabaseError catch (_) {
          //print(e);
          //print(e.runtimeType);
          // InvalidAccessError: A parameter or an operation was not supported by the underlying object. The storeNames parameter was empty.
        }
      });

      test('bad_store', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        try {
          transaction.objectStore(testStoreName2);
          fail("exception expected");
        } catch (e) {
          // NotFoundError: An attempt was made to reference a Node in a context where it does not exist. The specified object store was not found.
          expect(isNotFoundError(e), isTrue);
        }
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

    group('timing', () {
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

      test('get_after_completed', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);
        await transaction.completed;
        try {
          await objectStore.getObject(0);
        } on DatabaseError catch (e) {
          // Transaction inactive
          expect(isTransactionInactiveError(e), isTrue);
        }
      });

      test('transaction_async_get', () async {
        Transaction transaction;
        ObjectStore objectStore;
        _createTransactionSync() {
          transaction = db.transaction(testStoreName, idbModeReadWrite);
          objectStore = transaction.objectStore(testStoreName);
        }
        _createTransaction() async {
          await new Future.delayed(new Duration(milliseconds: 1));
          _createTransactionSync();
        }

        // Sync ok
        _createTransactionSync();
        await objectStore.getObject(0);
        await transaction.completed;

        // Async ok now even on Safari
        // this used to fail with a transactioninactiveerror
        await _createTransaction();
        await objectStore.getObject(0);

        await transaction.completed;
      });

      test('transaction_wait_get', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);

        // this cause the transaction to terminate on ie
        // and so on sembast
        await new Future.value();

        try {
          await objectStore.getObject(0);
          if (ctx.isIdbSembast || ctx.isIdbIe) {
            fail('should fail');
          }
        } on DatabaseError catch (e) {
          // Transaction inactive
          expect(e.message.contains("TransactionInactiveError"), isTrue);
        }
        await transaction.completed;
      });

      test('get_wait_get', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);

        // this cause the transaction to terminate on ie
        // and so on sembast
        await new Future.value();

        try {
          await objectStore.getObject(0);
          if (ctx.isIdbSembast || ctx.isIdbIe) {
            fail('should fail');
          }
        } on DatabaseError catch (e) {
          // Transaction inactive
          expect(e.message.contains("TransactionInactiveError"), isTrue);
        }
        await transaction.completed;
      });

      test('get_then_get', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);

        await objectStore.getObject(0).then((_) {
          // this cause the transaction to terminate on ie
          // and so on sembast
          new Future.value().then((_) {
            objectStore.getObject(0).then((_) {
              if (ctx.isIdbSembast || ctx.isIdbIe) {
                fail('should fail');
              }
            }).catchError((DatabaseError e) {
              // Transaction inactive
              expect(e.message.contains("TransactionInactiveError"), isTrue);
            }).then((_) {
              return transaction.completed;
            });
          });
        });
      });

      test('get_delay_get', () async {
        // this hangs on ie now
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);

        // this cause the transaction to terminate on every implementation
        await new Future.delayed(new Duration());

        try {
          await objectStore.getObject(0);
          fail('should fail');
          //} on DatabaseError catch (e) {
        } catch (e) {
          // Transaction inactive
          expect(e.message.contains("TransactionInactiveError"), isTrue);
        }

        // this hangs on idb, chrome ie/safari
        // if (!(ctx.isIdbIe || ctx.isIdbSafari)) {
        //  await transaction.completed;
      });

      test('get_wait_wait_get', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);
        // this cause the transaction to terminate on ie
        if (!ctx.isIdbNoLazy) {
          await new Future.value();
          await new Future.value();
        }
        await objectStore.getObject(0);
        await transaction.completed;
      });

      test('put_wait_wait_put', () async {
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.put({});
        // this cause the transaction to terminate on ie
        if (!ctx.isIdbNoLazy) {
          await new Future.value();
          await new Future.value();
        }
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
        // This somehow ones failed on ie 11 but works on edge
        // bah ugly bug for ie then...
        transaction2.objectStore(testStoreName).put("test").then((key) {
          expect(key, 2);
        });
        return Future.wait([transaction1.completed, transaction2.completed]);
      });
    });
  });
}
