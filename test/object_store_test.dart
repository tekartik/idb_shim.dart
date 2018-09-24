library object_store_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'idb_test_common.dart';
import 'common_meta_test.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;

  Database db;
  Transaction transaction;
  ObjectStore objectStore;

  _createTransaction() {
    transaction = db.transaction(testStoreName, idbModeReadWrite);
    objectStore = transaction.objectStore(testStoreName);
  }

  // new
  String _dbName;
  // prepare for test
  Future _setupDeleteDb() async {
    _dbName = ctx.dbName;
    await idbFactory.deleteDatabase(_dbName);
  }

  // generic tearDown
  _tearDown() async {
    if (transaction != null) {
      await transaction.completed;
      transaction = null;
    }
    if (db != null) {
      db.close();
      db = null;
    }
  }

  group('object_store', () {
    // Make testDbName less bad
    String testDbName = ctx.dbName;

    group('failure', () {
      setUp(() async {
        await idbFactory.deleteDatabase(testDbName);
      });

      test('create object store not in initialize', () {
        return idbFactory.open(testDbName).then((Database database) {
          try {
            database.createObjectStore(testStoreName, autoIncrement: true);
          } catch (e) {
            //print(e.runtimeType);
            database.close();
            return;
          }
          fail("should fail");
        });
      });
    });

    group('init', () {
      tearDown(_tearDown);

      test('delete', () async {
        await _setupDeleteDb();

        void _createStore(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName);
        }

        Database db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _createStore);
        Transaction txn = db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore store = txn.objectStore(testStoreName);
        await store.put("value", "key");
        expect(await store.getObject("key"), "value");
        await txn.completed;

        db.close();

        void _deleteAndCreateStore(VersionChangeEvent e) {
          Database db = e.database;
          db.deleteObjectStore(testStoreName);
          db.createObjectStore(testStoreName);
        }

        db = await idbFactory.open(_dbName,
            version: 2, onUpgradeNeeded: _deleteAndCreateStore);
        txn = db.transaction(testStoreName, idbModeReadOnly);
        store = txn.objectStore(testStoreName);
        expect(await store.getObject("key"), null);
        await txn.completed;
        db.close();
      });
    });

    group('non_auto', () {
      tearDown(_tearDown);

      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      test('properties', () async {
        await _setUp();
        _createTransaction();
        expect(objectStore.keyPath, null);
        expect(objectStore.name, testStoreName);
        expect(objectStore.indexNames, []);

        // ie weird missing feature
        if (ctx.isIdbIe) {
          expect(objectStore.autoIncrement, isNull);
        } else {
          expect(objectStore.autoIncrement, false);
        }
      });

      test('add/get map', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value, 123).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((readValue) {
            expect(readValue, value);
          });
        });
      });

      // not working in js firefox
      test('add_twice_same_key', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value, 123).then((key) {
          expect(key, 123);
          return transaction.completed.then((_) {
            _createTransaction();
            return objectStore.add(value, 123).then((_) {}, onError: (e) {
              transaction = null;
            }).then((_) {
              expect(transaction, null);
            });
          });
        });
      });

      test('add/get string', () async {
        await _setUp();
        _createTransaction();
        String value = "4567";
        return objectStore.add(value, 123).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((readValue) {
            expect(readValue, value);
          });
        });
      });

      test('getObject_null', () async {
        await _setUp();
        _createTransaction();
        try {
          await objectStore.getObject(null);
          fail("error");
        } catch (e) {
          expect(isTestFailure(e), isFalse);
          expect(e, isNotNull);
        }
      });

      test('getObject_boolean', () async {
        await _setUp();
        _createTransaction();
        try {
          await objectStore.getObject(true);
          fail("error");
        } catch (e) {
          expect(isTestFailure(e), isFalse);
          expect(e, isNotNull);
        }
      });

      test('put/get_key_double', () async {
        await _setUp();
        _createTransaction();
        String value = "test";
        expect(await objectStore.getObject(1.2), isNull);
        double key = 0.001;
        double keyAdded = await objectStore.add(value, key);
        expect(keyAdded, key);
        expect(await objectStore.getObject(key), value);
      });
    });

    group('auto', () {
      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('properties', () async {
        await _setUp();
        _createTransaction();
        expect(objectStore.keyPath, null);
        if (ctx.isIdbIe) {
          expect(objectStore.autoIncrement, isNull);
        } else {
          expect(objectStore.autoIncrement, true);
        }
      }, testOn: "!ie");

      // Good first test
      test('add', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value).then((key) {
          expect(key, 1);
        });
      });

      test('add2', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value).then((key) {
          expect(key, 1);
        }).then((_) {
          return objectStore.add(value).then((key) {
            expect(key, 2);
          });
        });
      });

      test('add with key and next', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value, 1234).then((key) {
          expect(key, 1234);
        }).then((_) {
          return objectStore.add(value).then((key) {
            if (ctx.isIdbSafari) {
              expect(key, 1);
            } else {
              expect(key, 1235);
            }
          });
        });
      });

      // limitation, this crashes everywhere
      test('add_with_same_key', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        int key = await objectStore.add(value, 1234);
        expect(key, 1234);
        try {
          await objectStore.add(value, 1234);
          fail("should fail");
        } catch (e) {
          expect(isTestFailure(e), isFalse);
        }
        // cancel transaction
        transaction = null;
      });

      test('add with key then back', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value, 1234).then((key) {
          expect(key, 1234);
        }).then((_) {
          return objectStore.add(value, 1232).then((key) {
            expect(key, 1232);
          });
        }).then((_) {
          return objectStore.add(value).then((key) {
            if (ctx.isIdbSafari) {
              expect(key, 1);
            } else {
              expect(key, 1235);
            }
          });
        });
      });

      // limitation
      // websql make it 3 while idb and sembast make it one...
      test('add_with_text_number_key_and_next', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        String key2 = await objectStore.add(value, "2");
        expect(key2, "2");
        int key1 = await objectStore.add(value);
        expect(key1 == 1 || key1 == 3, isTrue);
      });

      // limitation
      // Sql does not support text and auto increment
      test('add_with_text_key_and_next', () async {
        await _setUp();
        _createTransaction();
        Map value1 = {'test': 1};
        Map value2 = {'test': 2};
        String keyTest = await objectStore.add(value1, "test");
        expect(keyTest, "test");
        int key1 = await objectStore.add(value2);
        expect(key1, 1);

        Map valueRead = await objectStore.getObject(1);
        valueRead = await objectStore.getObject('test') as Map;
        expect(valueRead, value1);
      }, skip: true);

      test('get', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key).then((value) {
            expect(value.length, 0);
          });
        });
      });

      test('simple get', () async {
        await _setUp();
        _createTransaction();
        Map value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key).then((valueRead) {
            expect(value, valueRead);
          });
        });
      });

      test('get dummy', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key + 1).then((value) {
            expect(value, null);
          });
        });
      });

      test('get none', () async {
        await _setUp();
        _createTransaction();
        //Map value = {};
        return objectStore.getObject(1234).then((value) {
          expect(value, null);
        });
      });

      test('count_one', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        await objectStore.add(value);

        // crashes on ie
        if (!ctx.isIdbIe) {
          expect(await objectStore.count(), 1);
        }
      });

      test('count by key', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value).then((key1) {
          return objectStore.add(value).then((key2) {
            return objectStore.count(key1).then((int count) {
              expect(count, 1);
              return objectStore.count(key2).then((int count) {
                expect(count, 1);
              });
            });
          });
        });
      });

      test('count by range', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value).then((key1) {
          return objectStore.add(value).then((key2) {
            return objectStore
                .count(KeyRange.lowerBound(key1, true))
                .then((int count) {
              expect(count, 1);
              return objectStore
                  .count(KeyRange.lowerBound(key1))
                  .then((int count) {
                expect(count, 2);
              });
            });
          });
        });
      });

      test('count_empty', () async {
        // count() crashes on ie
        if (!ctx.isIdbIe) {
          await _setUp();
          _createTransaction();
          return objectStore.count().then((int count) {
            expect(count, 0);
          });
        }
      });

      test('delete', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value).then((key) {
          return objectStore.delete(key).then((_) {
            return objectStore.getObject(key).then((value) {
              expect(value, null);
            });
          });
        });
      });

      test('delete empty', () async {
        await _setUp();
        _createTransaction();
        return objectStore.getObject(1234).then((value) {
          expect(value, null);
        });
      });

      test('delete dummy', () async {
        await _setUp();
        _createTransaction();
        Map value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          return objectStore.delete(key + 1).then((delete_result) {
            // check fist one still here
            return objectStore.getObject(key).then((valueRead) {
              expect(value, valueRead);
            });
          });
        });
      });

      test('simple update', () async {
        await _setUp();
        _createTransaction();
        Map value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key).then((valueRead) {
            expect(value, valueRead);
            value['test'] = 'new_value';
            return objectStore.put(value, key).then((putResult) {
              expect(putResult, key);
              return objectStore.getObject(key).then((valueRead2) {
                expect(valueRead2, value);
                expect(valueRead2, isNot(equals(valueRead)));
              });
            });
          });
        });
      });

      test('update empty', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.put(value, 1234).then((value) {
          expect(value, 1234);
        });
      });

      test('update dummy', () async {
        await _setUp();
        _createTransaction();
        Map value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          Map newValue = cloneValue(value);
          newValue['test'] = 'new_value';
          return objectStore.put(newValue, key + 1).then((delete_result) {
            // check fist one still here
            return objectStore.getObject(key).then((valueRead) {
              expect(value, valueRead);
            });
          });
        });
      });

      test('clear', () async {
        await _setUp();
        _createTransaction();
        Map value = {};
        return objectStore.add(value).then((key) {
          return objectStore.clear().then((clearResult) {
            expect(clearResult, null);

            return objectStore.getObject(key).then((value) {
              expect(value, null);
            });
          });
        });
      });

      test('clear empty', () async {
        await _setUp();
        _createTransaction();
        return objectStore.clear().then((clearResult) {
          expect(clearResult, null);
        });
      });
    });

    // skipped for firefox
    group('readonly', () {
      _createTransaction() {
        transaction = db.transaction(testStoreName, idbModeReadOnly);
        objectStore = transaction.objectStore(testStoreName);
      }

      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('add', () async {
        await _setUp();
        _createTransaction();
        return objectStore.add({}, 1).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTestFailure(e), isFalse);
          expect(isTransactionReadOnlyError(e), isTrue);
          // don't wait for transaction
          transaction = null;
        });
      });

      test('put', () async {
        await _setUp();
        _createTransaction();
        return objectStore.put({}, 1).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTestFailure(e), isFalse);
          expect(isTransactionReadOnlyError(e), isTrue);
          // don't wait for transaction
          transaction = null;
        });
      });

      test('clear', () async {
        await _setUp();
        _createTransaction();
        return objectStore.clear().catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTestFailure(e), isFalse);
          expect(isTransactionReadOnlyError(e), isTrue);
          // don't wait for transaction
          transaction = null;
        });
      });

      test('delete', () async {
        await _setUp();
        _createTransaction();
        return objectStore.delete(1).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTestFailure(e), isFalse);
          expect(isTransactionReadOnlyError(e), isTrue);
          // don't wait for transaction
          transaction = null;
        });
      });
    });

    group('key_path_auto', () {
      const String keyPath = "my_key";

      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName,
              keyPath: keyPath, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('properties', () async {
        await _setUp();
        _createTransaction();
        expect(objectStore.keyPath, keyPath);

        if (ctx.isIdbIe) {
          expect(objectStore.autoIncrement, isNull);
        } else {
          expect(objectStore.autoIncrement, true);
        }
      });

      test('simple get', () async {
        await _setUp();
        _createTransaction();
        Map value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          expect(key, 1);
          return objectStore.getObject(key).then((valueRead) {
            Map expectedValue = cloneValue(value);
            expectedValue[keyPath] = 1;
            expect(valueRead, expectedValue);
          });
        });
      });

      test('simple add with keyPath and next', () async {
        await _setUp();
        _createTransaction();
        Map value = {'test': 'test_value', keyPath: 123};
        return objectStore.add(value).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((valueRead) {
            expect(value, valueRead);
          });
        }).then((_) {
          Map value = {
            'test': 'test_value',
          };
          return objectStore.add(value).then((key) {
            // On Safari this is 1
            if (ctx.isIdbSafari) {
              expect(key, 1);
            } else {
              expect(key, 124);
            }
          });
        });
      });

      test('put with keyPath', () async {
        await _setUp();
        _createTransaction();
        Map value = {'test': 'test_value', keyPath: 123};
        return objectStore.put(value).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((valueRead) {
            expect(value, valueRead);
          });
        });
      });

      test('add key and keyPath', () async {
        await _setUp();
        _createTransaction();
        Map value = {'test': 'test_value', keyPath: 123};
        return objectStore.add(value, 123).then((_) {
          fail("should fail");
        }, onError: (e, st) {
          // "both key 123 and inline keyPath 123 are specified
          //devPrint(e);
          // mark transaction as null
          transaction = null;
        });
      });

      test('put key and keyPath', () async {
        await _setUp();
        _createTransaction();
        Map value = {'test': 'test_value', keyPath: 123};
        return objectStore.put(value, 123).then((_) {
          fail("should fail");
        }, onError: (e) {
          //print(e);
          transaction = null;
        });
      });
    });

    group('key_path_non_auto', () {
      const String keyPath = "my_key";

      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, keyPath: keyPath);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('properties', () async {
        await _setUp();
        _createTransaction();
        expect(objectStore.keyPath, keyPath);
        if (ctx.isIdbIe) {
          expect(objectStore.autoIncrement, isNull);
        } else {
          expect(objectStore.autoIncrement, false);
        }
      });

      test('simple add_get', () async {
        await _setUp();
        _createTransaction();
        Map value = {keyPath: 'test_value'};
        return objectStore.add(value).then((key) {
          expect(key, 'test_value');
          return objectStore.getObject(key).then((valueRead) {
//               Map expectedValue = cloneValue(value);
//               expectedValue[keyPath] = 1;
            expect(valueRead, value);
          });
        });
      });

      test('simple put_get', () async {
        await _setUp();
        _createTransaction();
        Map value = {keyPath: 'test_value'};
        return objectStore.put(value).then((key) {
          expect(key, 'test_value');
          return objectStore.getObject(key).then((valueRead) {
//               Map expectedValue = cloneValue(value);
//               expectedValue[keyPath] = 1;
            expect(valueRead, value);
          });
        });
      });

      test('add_null', () async {
        await _setUp();
        _createTransaction();
        Map value = {"dummy": 'test_value'};
        return objectStore.add(value).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          //expect(isTransactionReadOnlyError(e), isTrue);
          //devPrint(e);
          // IdbMemoryError(3): neither keyPath nor autoIncrement set and trying to add object without key
          expect(isTestFailure(e), isFalse);
          //expect(e is DatabaseError, isTrue);
          transaction = null;
        });
      });

      test('put_null', () async {
        await _setUp();
        _createTransaction();
        Map value = {"dummy": 'test_value'};
        return objectStore.put(value).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          //expect(isTransactionReadOnlyError(e), isTrue);
          //devPrint(e);
          expect(isTestFailure(e), isFalse);
          //expect(e is DatabaseError, isTrue);
          transaction = null;
        });
      });

      test('add_twice', () async {
        await _setUp();
        _createTransaction();
        Map value = {keyPath: 'test_value'};
        return objectStore.add(value).then((key) {
          expect(key, 'test_value');
          return objectStore.add(value).catchError((e) {
            // There must be an error!
            return e;
          }).then((e) {
            //expect(isTransactionReadOnlyError(e), isTrue);
            //devPrint(e);
            // expect(e is DatabaseError, isTrue);
            expect(isTestFailure(e), isFalse);

            // in native completed will never succeed so remove it
            transaction = null;
          });
        });
      });

      // put twice should be fine
      test('put_twice', () async {
        await _setUp();
        _createTransaction();
        Map value = {keyPath: 'test_value'};
        String key = await objectStore.put(value);
        expect(key, 'test_value');
        key = await objectStore.put(value) as String;

        // There must be only one item
        expect(await objectStore.count(key), 1);

        // count() crashes on ie
        if (!ctx.isIdbIe) {
          expect(await objectStore.count(), 1);
        }
      });
    });

    group('create store and re-open', () {
      setUp(() {
        return idbFactory.deleteDatabase(testDbName);
      });

      Future testStore(IdbObjectStoreMeta storeMeta) {
        return setUpSimpleStore(idbFactory, meta: storeMeta, dbName: testDbName)
            .then((Database db) {
          db.close();
        }).then((_) async {
          Database db = await idbFactory.open(testDbName);
          Transaction transaction =
              db.transaction(storeMeta.name, idbModeReadOnly);
          ObjectStore objectStore = transaction.objectStore(storeMeta.name);
          IdbObjectStoreMeta readMeta =
              IdbObjectStoreMeta.fromObjectStore(objectStore);

          // ie idb does not have autoIncrement
          if (ctx.isIdbIe) {
            readMeta = IdbObjectStoreMeta(readMeta.name, readMeta.keyPath,
                storeMeta.autoIncrement, readMeta.indecies.toList());
          }
          expect(readMeta, storeMeta);
          await transaction.completed;
          db.close();
        });
      }

      test('all', () {
        Iterator<IdbObjectStoreMeta> iterator = idbObjectStoreMetas.iterator;

        Future _next() {
          if (iterator.moveNext()) {
            return testStore(iterator.current).then((_) {
              return _next();
            });
          }
          return Future.value();
        }

        return _next();
      });
    });

    group('various', () {
      _setUp() async {
        await _setupDeleteDb();
        db = await setUpSimpleStore(idbFactory, dbName: _dbName);
      }

      tearDown(_tearDown);

      test('delete', () async {
        await _setUp();
        _createTransaction();
        return objectStore.add("test").then((key) {
          return objectStore.delete(key).then((result) {
            expect(result, isNull);
          });
        });
      });
    });

    group('multi_store', () {
      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
          db.createObjectStore(testStoreName2, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('simple add_get', () async {
        await _setUp();
        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        ObjectStore objectStore1 = transaction.objectStore(testStoreName);
        var key1 = await objectStore1.add("test_value1");
        expect(key1, 1);
        ObjectStore objectStore2 = transaction.objectStore(testStoreName2);
        var key2 = await objectStore2.add("test_value2");
        expect(key2, 1);
        await transaction.completed;

        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
        objectStore1 = transaction.objectStore(testStoreName);
        expect(await objectStore1.getObject(key1), "test_value1");
        objectStore2 = transaction.objectStore(testStoreName2);
        expect(await objectStore2.getObject(key2), "test_value2");
      });

      test('simple add_put_get', () async {
        await _setUp();
        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        ObjectStore objectStore1 = transaction.objectStore(testStoreName);
        var key1 = await objectStore1.add("test_value1");
        expect(key1, 1);
        ObjectStore objectStore2 = transaction.objectStore(testStoreName2);
        var key2 = await objectStore2.add("test_value2");
        expect(key2, 1);
        await transaction.completed;

        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        objectStore1 = transaction.objectStore(testStoreName);
        await objectStore1.put("update_value1", key1);
        objectStore2 = transaction.objectStore(testStoreName2);
        await objectStore2.put("update_value2", key2);
        await transaction.completed;

        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
        objectStore1 = transaction.objectStore(testStoreName);
        expect(await objectStore1.getObject(key1), "update_value1");
        objectStore2 = transaction.objectStore(testStoreName2);
        expect(await objectStore2.getObject(key2), "update_value2");
      });

      test('order_add_get', () async {
        await _setUp();
        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        ObjectStore objectStore1 = transaction.objectStore(testStoreName);
        var key1 = await objectStore1.add("test_value1");
        expect(key1, 1);
        objectStore1 = transaction.objectStore(testStoreName);
        var key1_1 = await objectStore1.add("test_value1_1");
        expect(key1_1, 2);
        ObjectStore objectStore2 = transaction.objectStore(testStoreName2);
        var key2 = await objectStore2.add("test_value2");
        expect(key2, 1);
        objectStore1 = transaction.objectStore(testStoreName);
        var key1_2 = await objectStore1.add("test_value1_2");
        expect(key1_2, 3);
        await transaction.completed;

        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
        objectStore1 = transaction.objectStore(testStoreName);
        expect(await objectStore1.getObject(key1), "test_value1");
        expect(await objectStore1.getObject(key1_1), "test_value1_1");
        expect(await objectStore1.getObject(key1_2), "test_value1_2");
        objectStore2 = transaction.objectStore(testStoreName2);
        expect(await objectStore2.getObject(key2), "test_value2");
      });
    });
  });
}
