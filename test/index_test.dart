library index_test;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';
import 'common_meta_test.dart';

// so that this can be run directly
main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;
  group('index', () {
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

    group('no', () {
      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
        _createTransaction();
      }

      tearDown(_tearDown);

      test('store_properties', () async {
        await _setUp();
        expect(objectStore.indexNames, isEmpty);
      });

      test('primary', () async {
        await _setUp();
        try {
          objectStore.index(null);
          fail("should fail");
        } catch (e) {
          // print(e);
        }
      });

      test('dummy', () async {
        await _setUp();
        try {
          objectStore.index("dummy");
          fail("should fail");
        } catch (e) {
          // print(e);
        }
      });
    });

    group('one not unique', () {
      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField, unique: false);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
        _createTransaction();
      }

      tearDown(_tearDown);

      test('add_twice_same_key', () async {
        await _setUp();
        Map value1 = {testNameField: "test1"};

        Index index = objectStore.index(testNameIndex);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value1).then((_) {
//            // create new transaction;
            index = objectStore.index(testNameIndex);
            return index.count(new KeyRange.only("test1")).then((int count) {
              expect(count == 2, isTrue);
            });
            // });
          });
        });
      });

      test('get_null', () async {
        await _setUp();
        Index index = objectStore.index(testNameIndex);
        try {
          await index.get(null);
          fail("error");
        } on DatabaseError catch (e) {
          expect(e, isNotNull);
        }
      });

      test('get_boolean', () async {
        await _setUp();
        Index index = objectStore.index(testNameIndex);
        try {
          await index.get(null);
          fail("error");
        } on DatabaseError catch (e) {
          expect(e, isNotNull);
        }
      });
      test('getKey_null', () async {
        await _setUp();
        Index index = objectStore.index(testNameIndex);
        try {
          await index.getKey(null);
          fail("error");
        } on DatabaseError catch (e) {
          expect(e, isNotNull);
        }
      });

      test('getKey_boolean', () async {
        await _setUp();
        Index index = objectStore.index(testNameIndex);
        try {
          await index.getKey(true);
          fail("error");
        } on DatabaseError catch (e) {
          expect(e, isNotNull);
        }
      });
//
//      solo_test('add_twice_same_key', () {
//        Map value1 = {
//          NAME_FIELD: "test1"
//        };
//
//        Index index = objectStore.index(NAME_INDEX);
//        objectStore.add(value1);
//        objectStore.add(value1);
//        return transaction.completed.then((_) {
////            // create new transaction;
//          _createTransaction();
//          index = objectStore.index(NAME_INDEX);
//          return index.count(new KeyRange.only("test1")).then((int count) {
//            expect(count == 2, isTrue);
//          });
//          // });
//        });
//      });
    });

    group('one unique', () {
      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField, unique: true);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
        _createTransaction();
      }

      tearDown(_tearDown);

      test('store_properties', () async {
        await _setUp();
        expect(objectStore.indexNames, [testNameIndex]);
      });

      test('properties', () async {
        await _setUp();
        Index index = objectStore.index(testNameIndex);
        expect(index.name, testNameIndex);
        expect(index.keyPath, testNameField);
        expect(index.multiEntry, false);
        expect(index.unique, true);
      });

      test('primary', () async {
        await _setUp();
        Index index = objectStore.index(testNameIndex);
        return index.count().then((result) {
          expect(result, 0);
        });
      });

      test('count by key', () async {
        await _setUp();
        Map value1 = {testNameField: "test1"};
        Map value2 = {testNameField: "test2"};
        Index index = objectStore.index(testNameIndex);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value2).then((_) {
            return index.count("test1").then((int count) {
              expect(count, 1);
              return index.count("test2").then((int count) {
                expect(count, 1);
              });
            });
          });
        });
      });

      test('count by range', () async {
        await _setUp();
        Map value1 = {testNameField: "test1"};
        Map value2 = {testNameField: "test2"};
        Index index = objectStore.index(testNameIndex);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value2).then((_) {
            return index
                .count(new KeyRange.lowerBound("test1", true))
                .then((int count) {
              expect(count, 1);
              return index
                  .count(new KeyRange.lowerBound("test1"))
                  .then((int count) {
                expect(count, 2);
              });
            });
          });
        });
      });

      test('WEIRD count by range', () async {
        await _setUp();
        Map value = {};
        return objectStore.add(value).then((key1) {
          return objectStore.add(value).then((key2) {
            return objectStore
                .count(new KeyRange.lowerBound(key1, true))
                .then((int count) {
              expect(count, 1);
              return objectStore
                  .count(new KeyRange.lowerBound(key1))
                  .then((int count) {
                expect(count, 2);
              });
            });
          });
        });
      }, skip: true);

      test('add/get map', () async {
        await _setUp();
        Map value = {testNameField: "test1"};
        Index index = objectStore.index(testNameIndex);
        return objectStore.add(value).then((key) {
          return index.get("test1").then((Map readValue) {
            expect(readValue, value);
          });
        });
      });

      test('get key none', () async {
        await _setUp();
        Index index = objectStore.index(testNameIndex);
        return index.getKey("test1").then((int readKey) {
          expect(readKey, isNull);
        });
      });

      test('add/get key', () async {
        await _setUp();
        Map value = {testNameField: "test1"};
        Index index = objectStore.index(testNameIndex);
        return objectStore.add(value).then((int key) {
          return index.getKey("test1").then((int readKey) {
            expect(readKey, key);
          });
        });
      });

      test('add_twice_same_key', () async {
        await _setUp();
        Map value1 = {testNameField: "test1"};

        Index index = objectStore.index(testNameIndex);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value1).catchError((DatabaseError e) {
            //devPrint(e);
          }).then((_) {
//            // create new transaction;
            _createTransaction();
            index = objectStore.index(testNameIndex);
            return index.count(new KeyRange.only("test1")).then((int count) {
              // 1 for websql sorry...
              // devPrint(count);
              expect(count == 0 || count == 1, isTrue);
            });
            // });
          });
        });
      });

      test('add/get 2', () async {
        await _setUp();
        Map value1 = {testNameField: "test1"};
        Map value2 = {testNameField: "test2"};
        return objectStore.add(value1).then((key) {
          expect(key, 1);
          return objectStore.add(value2).then((key) {
            expect(key, 2);
            Index index = objectStore.index(testNameIndex);
            return index.get("test1").then((Map readValue) {
              expect(readValue, value1);
              return index.get("test2").then((Map readValue) {
                expect(readValue, value2);
                return index.count().then((result) {
                  expect(result, 2);
                });
              });
            });
          });
        });
      });
    });

    group('one_multi_entry', () {
      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              multiEntry: true);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
        _createTransaction();
      }

      tearDown(_tearDown);

      test('store_properties', () async {
        await _setUp();
        expect(objectStore.indexNames, [testNameIndex]);
      });

      test('properties', () async {
        await _setUp();
        Index index = objectStore.index(testNameIndex);
        expect(index.name, testNameIndex);
        expect(index.keyPath, testNameField);
        expect(index.multiEntry, true);
        expect(index.unique, false);
      });

      test('add_one', () async {
        await _setUp();
        Map value = {testNameField: "test1"};

        Index index = objectStore.index(testNameIndex);
        return objectStore.add(value).then((key) {
          return index.get("test1").then((Map readValue) {
            expect(readValue, value);
          });
        });
      });

      test('add_twice_same_key', () async {
        await _setUp();
        Map value = {testNameField: "test1"};

        Index index = objectStore.index(testNameIndex);
        return objectStore.add(value).then((key) {
          return objectStore.add(value).then((key) {
            return index.get("test1").then((Map readValue) {
              expect(readValue, value);
            });
          });
        });
      });

      test('add_null', () async {
        await _setUp();
        Map value = {"dummy": "value"};

        // There was a bug in memory implementation when a key was null
        Index index = objectStore.index(testNameIndex);
        return objectStore.add(value).then((key) {
          // get(null) does not work
          return index.count().then((int count) {
            expect(count, 0);
          });
        });
      });

      test('add_null_first', () async {
        await _setUp();
        Map value = {testNameField: "test1"};

        // There was a bug in memory implementation when a key was null
        Index index = objectStore.index(testNameIndex);
        return objectStore.add({}).then((key) {
          return objectStore.add(value).then((key) {
            return index.get("test1").then((Map readValue) {
              expect(readValue, value);
            });
          });
        });
      });
    });

    group('two_indecies', () {
      _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              multiEntry: true);
          objectStore.createIndex(testNameIndex2, testNameField2, unique: true);
        }
        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
        _createTransaction();
      }

      tearDown(_tearDown);

      test('store_properties', () async {
        await _setUp();
        expect(objectStore.indexNames, [testNameIndex, testNameIndex2]);
      });

      test('properties', () async {
        await _setupDeleteDb();
        Index index = objectStore.index(testNameIndex);
        expect(index.name, testNameIndex);
        expect(index.keyPath, testNameField);
        expect(index.multiEntry, true);
        expect(index.unique, false);

        index = objectStore.index(testNameIndex2);
        expect(index.name, testNameIndex2);
        expect(index.keyPath, testNameField2);
        expect(index.multiEntry, false);
        expect(index.unique, true);
      });
    });

    group('create index and re-open', () {
      Future testIndex(IdbIndexMeta indexMeta) async {
        await _setupDeleteDb();
        IdbObjectStoreMeta storeMeta = idbSimpleObjectStoreMeta.clone();
        storeMeta.putIndex(indexMeta);
        return setUpSimpleStore(idbFactory, meta: storeMeta, dbName: _dbName)
            .then((Database db) {
          db.close();
        }).then((_) {
          return idbFactory.open(_dbName).then((Database db) {
            Transaction transaction =
                db.transaction(storeMeta.name, idbModeReadOnly);
            ObjectStore objectStore = transaction.objectStore(storeMeta.name);
            Index index = objectStore.index(indexMeta.name);
            IdbIndexMeta readMeta = new IdbIndexMeta.fromIndex(index);
            expect(readMeta, indexMeta);
            db.close();
          });
        });
      }

      test('all', () {
        Iterator<IdbIndexMeta> iterator = idbIndexMetas.iterator;
        _next() {
          if (iterator.moveNext()) {
            return testIndex(iterator.current).then((_) {
              return _next();
            });
          }
        }
        return _next();
      });
    });
  });
}
