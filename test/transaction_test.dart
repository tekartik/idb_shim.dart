library transaction_test_common;

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;

  // new
  Database db;
  Transaction transaction;

  String _dbName;
  // prepare for test
  Future _setupDeleteDb() async {
    _dbName = ctx.dbName;
    await idbFactory.deleteDatabase(_dbName);
  }

  Future _tearDown() async {
    if (transaction != null) {
      await transaction.completed;
      transaction = null;
    }
    if (db != null) {
      db.close();
      db = null;
    }
  }

  group('transaction', () {
    //String testDbName = ctx.dbName;
    group('scratch', () {
      tearDown(_tearDown);

      test('put & completed', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        bool putDone = false;
        // ignore: unawaited_futures
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

        db = await idbFactory.open(_dbName,
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
            .open(_dbName, version: 1, onUpgradeNeeded: _initializeDatabase)
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

        db = await idbFactory.open(_dbName,
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
        Transaction transaction = db
            .transactionList([testStoreName, testStoreName2], idbModeReadWrite);
        await transaction.completed;
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
          expect(e is TestFailure, isFalse);
          // There must be an error!
          //print(e);
          //print(e.runtimeType);
          return e;
        }).then((e) {
          // there must be an error
          expect(e is TestFailure, isFalse);
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
          expect(isTestFailure(e), isFalse);
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
        } catch (e) {
          expect(e is TestFailure, isFalse);
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
          expect(e is TestFailure, isFalse);
          expect(isNotFoundError(e), isTrue);
        }
      });
    });

    group('simple', () {
      group('transaction auto', () {
        //ObjectStore objectStore;

        Future _setUp() async {
          await _setupDeleteDb();

          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            db.createObjectStore(testStoreName, autoIncrement: true);
          }

          return idbFactory
              .open(_dbName, version: 1, onUpgradeNeeded: _initializeDatabase)
              .then((Database database) {
            db = database;
            //transaction = db.transaction(testStoreName, idbModeReadWrite);
            //transaction.objectStore(testStoreName);
            return db;
          });
        }

        tearDown(_tearDown);

        test('immediate completed', () async {
          await _setUp();
          //bool done = false;
          Transaction transaction =
              db.transaction(testStoreName, idbModeReadWrite);
          return transaction.completed;
        });

        test('add immediate completed', () async {
          await _setUp();
          // not working in memory
          // devPrint("***** ${idbFactory.name}");
          if (idbFactory.name != idbFactoryWebSql) {
            bool done = false;
            Transaction transaction =
                db.transaction(testStoreName, idbModeReadWrite);
            ObjectStore objectStore = transaction.objectStore(testStoreName);
            // ignore: unawaited_futures
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
        test('immediate completed then add', () async {
          await _setUp();
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
            // ignore: unawaited_futures
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

      Future _setUp() async {
        return setUpSimpleStore(idbFactory, dbName: ctx.dbName)
            .then((Database database) {
          db = database;
        });
      }

      tearDown(_tearDown);

      test('immediate completed', () async {
        await _setUp();
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        return transaction.completed;
      });

      test('add immediate completed', () async {
        await _setUp();
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        // ignore: unawaited_futures
        objectStore.add("value1").then((key1) {
          done = true;
        });
        return transaction.completed.then((_) {
          expect(done, isTrue);
          //db.close();
          // done();
        });
      });

      test('add 1 then 1 immediate completed', () async {
        await _setUp();
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        // ignore: unawaited_futures
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
        await _setUp();
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);
        await objectStore.getObject(0);
        await transaction.completed;
      });

      test('get_after_completed', () async {
        await _setUp();
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);
        await transaction.completed;
        try {
          await objectStore.getObject(0);
        } catch (e) {
          // Transaction inactive
          expect(isTestFailure(e), isFalse);
          expect(isTransactionInactiveError(e), isTrue);
        }
      });

      test('transaction_async_get', () async {
        await _setUp();
        Transaction transaction;
        ObjectStore objectStore;
        void _createTransactionSync() {
          transaction = db.transaction(testStoreName, idbModeReadWrite);
          objectStore = transaction.objectStore(testStoreName);
        }

        Future _createTransaction() async {
          await Future.delayed(Duration(milliseconds: 1));
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
        await _setUp();
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);

        // In 1.12 this was causing the transaction to terminate on ie
        // this is no longer the case in 1.13
        await Future.value();
        await Future.value();
        await Future.value();

        await objectStore.getObject(0);

        await transaction.completed;
      });

      test('get_wait_get', () async {
        await _setUp();
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);

        // this cause the transaction to terminate on ie
        // and so on sembast
        await Future.value();

        try {
          await objectStore.getObject(0);
          if (ctx.isIdbNoLazy) {
            fail('should fail');
          }
          await transaction.completed;
        } catch (e) {
          // Transaction inactive
          expect(isTestFailure(e), isFalse);
          expect(isTransactionInactiveError(e), isTrue);
        }
      });

      test('get_async_get', () async {
        await _setUp();
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        Future _get() async {
          await objectStore.getObject(0);
        }

        await objectStore.getObject(0);
        try {
          await _get();
          // extra skeep
          // await new Future.delayed(new Duration(milliseconds: 1));
          if (ctx.isIdbNoLazy) {
            fail('should fail');
          }
          await transaction.completed;
        } catch (e) {
          expect(isTestFailure(e), isFalse, reason: e.toString());
          expect(isTransactionInactiveError(e), isTrue, reason: e.toString());
        }
      }, skip: "TODO");

      test('get_then_get', () async {
        await _setUp();
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);

        await objectStore.getObject(0).then((_) {
          // this cause the transaction to terminate on ie
          // and so on sembast
          Future.value().then((_) {
            objectStore.getObject(0).then((_) {
              if (ctx.isIdbSembast || ctx.isIdbIe) {
                fail('should fail');
              }
            }).catchError((e) {
              // Transaction inactive
              // print('edge error :$e');
              expect(isTestFailure(e), isFalse);
              expect(isTransactionInactiveError(e), isTrue);
            }).then((_) {
              return transaction.completed;
            });
          });
        });
      });

      test('get_delay_get', () async {
        await _setUp();
        // this hangs on ie now
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);

        // this cause the transaction to terminate on every implementation
        await Future.delayed(Duration());

        try {
          await objectStore.getObject(0);
          fail('should fail');
          //} on DatabaseError catch (e) {
        } catch (e) {
          expect(isTestFailure(e), isFalse);
          expect(isTransactionInactiveError(e), isTrue);
        }

        // this hangs on idb, chrome ie/safari
        // if (!(ctx.isIdbIe || ctx.isIdbSafari)) {
        //  await transaction.completed;
      });

      test('get_wait_wait_get', () async {
        await _setUp();
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadOnly);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(0);
        // this cause the transaction to terminate on ie
        if (!ctx.isIdbNoLazy) {
          await Future.value();
          await Future.value();
        }
        await objectStore.getObject(0);
        await transaction.completed;
      });

      test('put_wait_wait_put', () async {
        await _setUp();
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        await objectStore.put({});
        // this cause the transaction to terminate on ie
        if (!ctx.isIdbNoLazy) {
          await Future.value();
          await Future.value();
        }
        await objectStore.put({});
        await transaction.completed;
      });

      test('add 1 then 1 then 1 immediate completed', () async {
        await _setUp();
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        // ignore: unawaited_futures
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

      test('add 1 level 5 deep immediate completed', () async {
        await _setUp();
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        // ignore: unawaited_futures
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

      test('immediate completed then add', () async {
        await _setUp();
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
          // ignore: unawaited_futures
          objectStore.add("value1").then((key1) {
            done = true;
          });
          return completed;
        }
      });

      test('add 2 immediate completed', () async {
        await _setUp();
        bool done1 = false;
        bool done2 = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        // ignore: unawaited_futures
        objectStore.add("value1").then((key1) {
          expect(done1, isFalse);
          done1 = true;
        });
        // ignore: unawaited_futures
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

      test('add/put immediate completed', () async {
        await _setUp();
        if ((idbFactory.name != idbFactoryWebSql)) {
          bool done = false;
          Transaction transaction =
              db.transaction(testStoreName, idbModeReadWrite);
          ObjectStore objectStore = transaction.objectStore(testStoreName);
          // ignore: unawaited_futures
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

      test('add/put/get/delete', () async {
        await _setUp();
        bool done = false;
        Transaction transaction =
            db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        // ignore: unawaited_futures
        objectStore.add("value1").then((key1) {
          expect(key1, equals(1));

          objectStore.getObject(key1).then((value) {
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

      test('2 embedded transaction empty', () async {
        await _setUp();
        Transaction transaction1 =
            db.transaction(testStoreName, idbModeReadWrite);
        Transaction transaction2 =
            db.transaction(testStoreName, idbModeReadWrite);
        return Future.wait([transaction1.completed, transaction2.completed]);
      });

      test('2 embedded transaction 2 put', () async {
        await _setUp();
        Transaction transaction1 =
            db.transaction(testStoreName, idbModeReadWrite);
        Transaction transaction2 =
            db.transaction(testStoreName, idbModeReadWrite);
        // ignore: unawaited_futures
        transaction1.objectStore(testStoreName).put("test").then((key) {
          expect(key, 1);
        });
        // This somehow ones failed on ie 11 but works on edge
        // bah ugly bug for ie then...
        // ignore: unawaited_futures
        transaction2.objectStore(testStoreName).put("test").then((key) {
          expect(key, 2);
        });
        return Future.wait([transaction1.completed, transaction2.completed]);
      });
    });
  });
}
