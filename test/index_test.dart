library index_test;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

// so that this can be run directly
void main() {
  testMain(new IdbMemoryFactory());
}

void testMain(IdbFactory idbFactory) {

  group('index', () {
    group('no', () {

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

          });
        });
      });

      tearDown(() {
        return transaction.completed.then((_) {
          db.close();
        });
      });

      test('primary', () {
        try {
          objectStore.index(null);
          fail("should fail");
        } catch (e) {
          // print(e);
        }
      });

      test('dummy', () {
        try {
          objectStore.index("dummy");
          fail("should fail");
        } catch (e) {
          // print(e);
        }
      });
    });

    group('one unique', () {

      Database db;
      Transaction transaction;
      ObjectStore objectStore;

      _createTransaction() {
        transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
        objectStore = transaction.objectStore(STORE_NAME);
      }

      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
            Index index = objectStore.createIndex(NAME_INDEX, NAME_FIELD, unique: true);

          }
          return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
            db = database;
            _createTransaction();

          });
        });
      });

      tearDown(() {
        if (transaction != null) {
          return transaction.completed.then((_) {
            db.close();
          });
        } else {
          db.close();
        }
      });

      test('properties', () {
        Index index = objectStore.index(NAME_INDEX);
        expect(index.name, NAME_INDEX);
        expect(index.keyPath, NAME_FIELD);
        expect(index.multiEntry, false);
        expect(index.unique, true);
      });

      test('primary', () {
        Index index = objectStore.index(NAME_INDEX);
        return index.count().then((result) {
          expect(result, 0);
        });
      });

      test('count by key', () {
        Map value1 = {
          NAME_FIELD: "test1"
        };
        Map value2 = {
          NAME_FIELD: "test2"
        };
        Index index = objectStore.index(NAME_INDEX);
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

      test('count by range', () {
        Map value1 = {
          NAME_FIELD: "test1"
        };
        Map value2 = {
          NAME_FIELD: "test2"
        };
        Index index = objectStore.index(NAME_INDEX);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value2).then((_) {
            return index.count(new KeyRange.lowerBound("test1", true)).then((int count) {
              expect(count, 1);
              return index.count(new KeyRange.lowerBound("test1")).then((int count) {
                expect(count, 2);
              });
            });
          });
        });
      });

      skip_test('WEIRD count by range', () {
        Map value = {};
        return objectStore.add(value).then((key1) {
          return objectStore.add(value).then((key2) {
            return objectStore.count(new KeyRange.lowerBound(key1, true)).then((int count) {
              expect(count, 1);
              return objectStore.count(new KeyRange.lowerBound(key1)).then((int count) {
                expect(count, 2);
              });
            });
          });
        });
      });

      test('add/get map', () {
        Map value = {
          NAME_FIELD: "test1"
        };
        Index index = objectStore.index(NAME_INDEX);
        return objectStore.add(value).then((key) {
          return index.get("test1").then((Map readValue) {
            expect(readValue, value);
          });
        });

      });

      test('add/get key', () {
        Map value = {
          NAME_FIELD: "test1"
        };
        Index index = objectStore.index(NAME_INDEX);
        return objectStore.add(value).then((int key) {
          return index.getKey("test1").then((int readKey) {
            expect(readKey, key);
          });
        });

      });

      test('add_twice_same_key', () {
        Map value1 = {
          NAME_FIELD: "test1"
        };

        Index index = objectStore.index(NAME_INDEX);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value1).catchError((DatabaseError e) {
            //devPrint(e);
          }).then((_) {
//            // create new transaction;
            _createTransaction();
            index = objectStore.index(NAME_INDEX);
            return index.count(new KeyRange.only("test1")).then((int count) {
              // 1 for websql sorry...
              // devPrint(count);
              expect(count == 0 || count == 1, isTrue);
            });
            // });
          });
        });
      });

      test('add/get 2', () {
        Map value1 = {
          NAME_FIELD: "test1"
        };
        Map value2 = {
          NAME_FIELD: "test2"
        };
        return objectStore.add(value1).then((key) {
          expect(key, 1);
          return objectStore.add(value2).then((key) {
            expect(key, 2);
            Index index = objectStore.index(NAME_INDEX);
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

      Database db;
      Transaction transaction;
      ObjectStore objectStore;

      _createTransaction() {
        transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
        objectStore = transaction.objectStore(STORE_NAME);
      }

      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
            Index index = objectStore.createIndex(NAME_INDEX, NAME_FIELD, multiEntry: true);

          }
          return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
            db = database;
            _createTransaction();

          });
        });
      });

      tearDown(() {
        if (transaction != null) {
          return transaction.completed.then((_) {
            db.close();
          });
        } else {
          db.close();
        }
      });

      test('properties', () {
        Index index = objectStore.index(NAME_INDEX);
        expect(index.name, NAME_INDEX);
        expect(index.keyPath, NAME_FIELD);
        expect(index.multiEntry, true);
        expect(index.unique, false);
      });
    });
  });
}
