library index_test;

import 'package:unittest/unittest.dart';
import 'package:tekartik_idb/idb_client.dart';
import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

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
            transaction = db.transaction(STORE_NAME, MODE_READ_WRITE);
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

      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
            Index index = objectStore.createIndex(NAME_INDEX, NAME_FIELD, unique: true);
          }
          return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
            db = database;
            transaction = db.transaction(STORE_NAME, MODE_READ_WRITE);
            objectStore = transaction.objectStore(STORE_NAME);

          });
        });
      });

      tearDown(() {
        db.close();
      });

      test('primary', () {
        Index index = objectStore.index(NAME_INDEX);
        return index.count().then((result) {
          expect(result, 0);
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
            return transaction.completed;
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
  });
}
