library index_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_test/idb_test_common_meta.dart';

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;
  group('index', () {
    Database? db;
    Transaction? transaction;
    late ObjectStore objectStore;

    void dbCreateTransaction() {
      transaction = db!.transaction(testStoreName, idbModeReadWrite);
      objectStore = transaction!.objectStore(testStoreName);
    }

    // new
    late String dbName;
    // prepare for test
    Future setupDeleteDb() async {
      dbName = ctx.dbName;
      await idbFactory!.deleteDatabase(dbName);
    }

    // generic tearDown
    Future dbTearDown() async {
      if (transaction != null) {
        await transaction!.completed;
        transaction = null;
      }
      if (db != null) {
        db!.close();
        db = null;
      }
    }

    group('no', () {
      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory!
            .open(dbName, version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(dbTearDown);

      test('store_properties', () async {
        await dbSetUp();
        dbCreateTransaction();
        expect(objectStore.indexNames, isEmpty);
      });

      test('dummy', () async {
        await dbSetUp();
        dbCreateTransaction();
        try {
          objectStore.index('dummy');
          fail('should fail');
        } catch (e) {
          expect(isTestFailure(e), isFalse);
        }
      });
    });

    group('one not unique', () {
      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField, unique: false);
        }

        db = await idbFactory!
            .open(dbName, version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(dbTearDown);

      test('add_twice_same_key', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {testNameField: 'test1'};

        var index = objectStore.index(testNameIndex);
        await objectStore.add(value1);
        await objectStore.add(value1);
//            // create new transaction;
        index = objectStore.index(testNameIndex);
        final count = await index.count(KeyRange.only('test1'));
        expect(count, 2);
      });

      test('getKey_boolean', () async {
        await dbSetUp();
        dbCreateTransaction();
        final index = objectStore.index(testNameIndex);
        try {
          await index.getKey(true);
          fail('error');
        } catch (e) {
          expect(isTestFailure(e), isFalse);
          expect(e, isNotNull);
        }
      });

      test('getAll', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {testNameField: 'test1'};
        final value2 = {testNameField: 'test2'};
        final value3 = {testNameField: 'test1'};

        final index = objectStore.index(testNameIndex);
        expect(await index.getAll(), isEmpty);
        expect(await index.getAll(null, 1), isEmpty);
        expect(await index.getAll(1, 1), isEmpty);
        expect(await index.getAllKeys(), isEmpty);
        expect(await index.getAllKeys(null, 1), isEmpty);
        expect(await index.getAllKeys(1, 1), isEmpty);
        var key = await objectStore.put(value1, 1);
        expect(key, 1);
        key = await objectStore.add(value2, 2);
        expect(key, 2);
        await objectStore.add(value3, 3);

        expect(await index.getAll('test1'), [
          {'name': 'test1'},
          {'name': 'test1'}
        ]);
        expect(await index.getAllKeys('test1'), [1, 3]);
        expect(await index.getAll('test1', 1), [
          {'name': 'test1'}
        ]);
        expect(await index.getAllKeys('test1', 1), [1]);
        expect(await index.getAll(), [
          {'name': 'test1'},
          {'name': 'test1'},
          {'name': 'test2'},
        ]);
        expect(await index.getAllKeys(), [1, 3, 2]);
      });
//
//      solo_test('add_twice_same_key', () {
//        Map value1 = {
//          NAME_FIELD: 'test1'
//        };
//
//        Index index = objectStore.index(NAME_INDEX);
//        objectStore.add(value1);
//        objectStore.add(value1);
//        return transaction.completed.then((_) {
////            // create new transaction;
//          dbCreateTransaction();
//          index = objectStore.index(NAME_INDEX);
//          return index.count(new KeyRange.only('test1')).then((int count) {
//            expect(count == 2, isTrue);
//          });
//          // });
//        });
//      });
    });

    group('one unique', () {
      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField, unique: true);
        }

        db = await idbFactory!
            .open(dbName, version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(dbTearDown);

      test('store_properties', () async {
        await dbSetUp();
        dbCreateTransaction();
        expect(objectStore.indexNames, [testNameIndex]);
      });

      test('properties', () async {
        await dbSetUp();
        dbCreateTransaction();
        final index = objectStore.index(testNameIndex);
        expect(index.name, testNameIndex);
        expect(index.keyPath, testNameField);
        // Not supported on ie
        if (!ctx.isIdbIe) {
          expect(index.multiEntry, false);
        }
        expect(index.unique, true);
      });

      test('primary', () async {
        await dbSetUp();
        dbCreateTransaction();
        final index = objectStore.index(testNameIndex);

        // count() crashes on ie
        if (!ctx.isIdbIe) {
          expect(await index.count(), 0);
        }
      });

      test('count by key', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {testNameField: 'test1'};
        final value2 = {testNameField: 'test2'};
        final index = objectStore.index(testNameIndex);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value2).then((_) {
            return index.count('test1').then((int count) {
              expect(count, 1);
              return index.count('test2').then((int count) {
                expect(count, 1);
              });
            });
          });
        });
      });

      test('count by range', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {testNameField: 'test1'};
        final value2 = {testNameField: 'test2'};
        final index = objectStore.index(testNameIndex);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value2).then((_) {
            return index
                .count(KeyRange.lowerBound('test1', true))
                .then((int count) {
              expect(count, 1);
              return index
                  .count(KeyRange.lowerBound('test1'))
                  .then((int count) {
                expect(count, 2);
              });
            });
          });
        });
      });

      test('WEIRD count by range', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {};
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
      }, skip: true);

      test('add/get map', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {testNameField: 'test1'};
        final index = objectStore.index(testNameIndex);
        var key = await objectStore.add(value);
        expect(key, 1);
        var readValue = await index.get('test1');
        expect(readValue, value);
      });

      test('get key none', () async {
        await dbSetUp();
        dbCreateTransaction();
        final index = objectStore.index(testNameIndex);
        var readKey = await index.getKey('test1');
        expect(readKey, isNull);
      });

      test('add/get key', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {testNameField: 'test1'};
        final index = objectStore.index(testNameIndex);
        var key = await objectStore.add(value);
        var readKey = await index.getKey('test1');
        expect(readKey, key);
      });

      test('add_twice_same_key', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {testNameField: 'test1'};

        var index = objectStore.index(testNameIndex);
        await objectStore.add(value1);
        try {
          await objectStore.add(value1);
          fail('should fail');
        } catch (e) {
          expect(e, isNot(const TypeMatcher<TestFailure>()));
        }
        // indexed db throw the exception during completed too...
        try {
          await transaction!.completed;
        } catch (_) {}
        // create new transaction;
        dbCreateTransaction();
        index = objectStore.index(testNameIndex);
        final count = await index.count(KeyRange.only('test1'));
        // 1 for websql sorry...
        // 2 for Safari idb, sorry...
        // devPrint(count);
        // Safari fails here!
        if (ctx.isIdbSafari) {
          expect(count, 2);
        } else {
          expect(count == 0 || count == 1, isTrue);
        }
      });

      test('add/get 2', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {testNameField: 'test1'};
        final value2 = {testNameField: 'test2'};
        var key = await objectStore.add(value1);
        expect(key, 1);
        key = await objectStore.add(value2);
        expect(key, 2);
        final index = objectStore.index(testNameIndex);
        var readValue = await index.get('test1');
        expect(readValue, value1);
        readValue = await index.get('test2');
        expect(readValue, value2);

        // count() crashes on ie
        if (!ctx.isIdbIe) {
          var result = await index.count();
          expect(result, 2);
        }
      });
    });

    group('key_path_with_dot', () {
      var keyPath = 'my.key';

      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, keyPath);
        }

        db = await idbFactory!
            .open(dbName, version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(dbTearDown);

      test('store_properties', () async {
        await dbSetUp();
        dbCreateTransaction();
        expect(objectStore.indexNames, [testNameIndex]);
      });

      test('count by key', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {
          'my': {'key': 'test1'}
        };
        final value2 = {
          'my': {'key': 'test2'}
        };
        final index = objectStore.index(testNameIndex);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value2).then((_) {
            return index.count('test1').then((int count) {
              expect(count, 1);
              return index.count('test2').then((int count) {
                expect(count, 1);
              });
            });
          });
        });
      });

      test('count by range', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {
          'my': {'key': 'test1'}
        };
        final value2 = {
          'my': {'key': 'test2'}
        };
        final index = objectStore.index(testNameIndex);
        return objectStore.add(value1).then((_) {
          return objectStore.add(value2).then((_) {
            return index
                .count(KeyRange.lowerBound('test1', true))
                .then((int count) {
              expect(count, 1);
              return index
                  .count(KeyRange.lowerBound('test1'))
                  .then((int count) {
                expect(count, 2);
              });
            });
          });
        });
      });

      test('WEIRD count by range', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {};
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
      }, skip: true);

      test('add/get map', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {
          'my': {'key': 'test1'}
        };
        final index = objectStore.index(testNameIndex);
        var key = await objectStore.add(value);
        expect(key, 1);
        var readValue = await index.get('test1');
        expect(readValue, value);
      });

      test('get key none', () async {
        await dbSetUp();
        dbCreateTransaction();
        final index = objectStore.index(testNameIndex);
        var readKey = await index.getKey('test1');
        expect(readKey, isNull);
      });

      test('add/get key', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {
          'my': {'key': 'test1'}
        };
        final index = objectStore.index(testNameIndex);
        var key = await objectStore.add(value);
        var readKey = await index.getKey('test1');
        expect(readKey, key);
      });

      test('add/get 2', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {
          'my': {'key': 'test1'}
        };
        final value2 = {
          'my': {'key': 'test2'}
        };
        var key = await objectStore.add(value1);
        expect(key, 1);
        key = await objectStore.add(value2);
        expect(key, 2);
        final index = objectStore.index(testNameIndex);
        var readValue = await index.get('test1');
        expect(readValue, value1);
        readValue = await index.get('test2');
        expect(readValue, value2);

        // count() crashes on ie
        if (!ctx.isIdbIe) {
          var result = await index.count();
          expect(result, 2);
        }
      });
    });

    group('multi_entry_true', () {
      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              multiEntry: true);
        }

        db = await idbFactory!
            .open(dbName, version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(dbTearDown);

      test('store_properties', () async {
        await dbSetUp();
        dbCreateTransaction();
        expect(objectStore.indexNames, [testNameIndex]);
      });

      test('properties', () async {
        await dbSetUp();
        dbCreateTransaction();
        final index = objectStore.index(testNameIndex);
        expect(index.name, testNameIndex);
        expect(index.keyPath, testNameField);

        // multiEntry not supported on ie
        if (!ctx.isIdbIe) {
          expect(index.multiEntry, true);
        }
        expect(index.unique, false);
      });

      test('add_one', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {testNameField: 'test1'};

        final index = objectStore.index(testNameIndex);
        var key = await objectStore.add(value);
        expect(key, 1);
        var readValue = await index.get('test1');
        expect(readValue, value);
      });

      test('add_one_array', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {
          testNameField: [1, 2]
        };

        final index = objectStore.index(testNameIndex);
        var key = await objectStore.add(value);
        expect(key, 1);
        var readValue = await index.get(1);
        expect(readValue, value);
      });

      test('add_two_arrays', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {
          testNameField: [1, 2]
        };
        final value2 = {
          testNameField: [1, 3]
        };
        final index = objectStore.index(testNameIndex);
        var key1 = await objectStore.add(value1);
        var key2 = await objectStore.add(value2);
        expect(key1, 1);
        expect(key2, 2);
        expect(await index.get(1), value1);
        expect(await index.get(2), value1);
        expect(await index.get(3), value2);
      });

      test('issue#2', () async {
        await setupDeleteDb();

        // open the database
        db = await idbFactory!.open(dbName, version: 1,
            onUpgradeNeeded: (VersionChangeEvent event) {
          final db = event.database;
          // create the store
          final store = db.createObjectStore('test', autoIncrement: true);
          store.createIndex('index', 'spath', multiEntry: true);
        });

        // put some data
        final object = <String, Object?>{
          'spath': [1, 2]
        };
        var txn = db!.transaction('test', 'readwrite');
        var store = txn.objectStore('test');
        await store.put(object);
        await txn.completed;

        // read some data
        txn = db!.transaction('test', 'readonly');
        store = txn.objectStore('test');
        var cursorStream = store
            .index('index')
            .openCursor(range: KeyRange.lowerBound(2), autoAdvance: true)
            .map((cv) => cv.value);
        expect(cursorStream, emits(object));
        await txn.completed;

        // read some data
        txn = db!.transaction('test', 'readonly');
        store = txn.objectStore('test');
        cursorStream = store
            .index('index')
            .openCursor(range: KeyRange.lowerBound(3), autoAdvance: true)
            .map((cv) => cv.value);
        expect(await cursorStream.toList(), isEmpty);
        await txn.completed;
      });

      test('add_twice_same_key', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {testNameField: 'test1'};

        final index = objectStore.index(testNameIndex);
        await objectStore.add(value);
        var readValue = await index.get('test1');
        expect(readValue, value);
      });

      test('add_null', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {'dummy': 'value'};

        // There was a bug in memory implementation when a key was null
        final index = objectStore.index(testNameIndex);
        await objectStore.add(value).then((key) async {
          // get(null) does not work

          // count() crashes on ie
          if (!ctx.isIdbIe) {
            expect(await index.count(), 0);
          }
        });
      });

      test('add_null_first', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {testNameField: 'test1'};

        // There was a bug in memory implementation when a key was null
        final index = objectStore.index(testNameIndex);
        await objectStore.add({});
        await objectStore.add(value);
        var readValue = await index.get('test1');
        expect(readValue, value);
      });

      test('getAll', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {testNameField: 1};
        final value2 = {
          testNameField: [2, 3]
        };
        final value3 = {
          testNameField: [1, 2]
        };

        final index = objectStore.index(testNameIndex);
        expect(await index.getAll(), isEmpty);
        expect(await index.getAll(null, 1), isEmpty);
        expect(await index.getAll(1, 1), isEmpty);
        expect(await index.getAllKeys(), isEmpty);
        expect(await index.getAllKeys(null, 1), isEmpty);
        expect(await index.getAllKeys(1, 1), isEmpty);
        var key = await objectStore.put(value1, 1);
        expect(key, 1);
        key = await objectStore.add(value2, 2);
        expect(key, 2);
        await objectStore.add(value3, 3);

        expect(await index.getAll(1), [
          {'name': 1},
          {
            'name': [1, 2]
          }
        ]);
        expect(await index.getAllKeys(1), [1, 3]);
        expect(await index.getAll(1, 1), [
          {'name': 1}
        ]);
        expect(await index.getAllKeys(1, 1), [1]);

        try {
//        only work on native
          expect(await index.getAll(), [
            {'name': 1},
            {
              'name': [1, 2]
            },
            {
              'name': [2, 3]
            },
            {
              'name': [1, 2]
            },
            {
              'name': [2, 3]
            }
          ]);
          expect(await index.getAllKeys(), [1, 3, 2, 3, 2]);
        } on TestFailure catch (_) {
          // print('Index.getAll multi entry allow failure $e');
          expect(await index.getAll(), [
            {'name': 1},
            {
              'name': [1, 2]
            },
            {
              'name': [2, 3]
            },
          ]);
          expect(await index.getAllKeys(), [1, 3, 2]);
        }
      });
    });

    group('multi_entry_false', () {
      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              multiEntry: false);
        }

        db = await idbFactory!
            .open(dbName, version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(dbTearDown);

      test('store_properties', () async {
        await dbSetUp();
        dbCreateTransaction();
        expect(objectStore.indexNames, [testNameIndex]);
      });

      test('properties', () async {
        await dbSetUp();
        dbCreateTransaction();
        final index = objectStore.index(testNameIndex);
        expect(index.name, testNameIndex);
        expect(index.keyPath, testNameField);

        // multiEntry not supported on ie
        if (!ctx.isIdbIe) {
          expect(index.multiEntry, false);
        }
        expect(index.unique, false);
      });

      test('add_one', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {testNameField: 'test1'};

        final index = objectStore.index(testNameIndex);
        var key = await objectStore.add(value);
        expect(key, 1);
        var readValue = await index.get('test1');
        expect(readValue, value);

        // Add again
        key = await objectStore.add(value);
        expect(key, 2);
      });

      test('add_one_array', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {
          testNameField: [1, 2]
        };

        final index = objectStore.index(testNameIndex);
        try {
          var key = await objectStore.add(value);
          expect(key, 1);
        } catch (_) {
          // This crashes on sqflite, normal as this is not supported...
          // Allow failure
          // devPrint(e);
        }
        var readValue = await index.get(1);
        expect(readValue, isNull);
      });
      test('getAll', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {testNameField: 1};
        final value2 = {
          testNameField: [2, 3]
        };
        final value3 = {
          testNameField: [1, 2]
        };

        final index = objectStore.index(testNameIndex);
        expect(await index.getAll(), isEmpty);
        expect(await index.getAll(null, 1), isEmpty);
        expect(await index.getAll(1, 1), isEmpty);
        expect(await index.getAllKeys(), isEmpty);
        expect(await index.getAllKeys(null, 1), isEmpty);
        expect(await index.getAllKeys(1, 1), isEmpty);
        var key = await objectStore.put(value1, 1);
        expect(key, 1);
        key = await objectStore.add(value2, 2);
        expect(key, 2);
        await objectStore.add(value3, 3);

        expect(await index.getAll(1), [
          {'name': 1},
        ]);
        expect(await index.getAllKeys(1), [1]);
        expect(await index.getAll(), [
          {'name': 1},
          {
            'name': [1, 2]
          },
          {
            'name': [2, 3]
          }
        ]);
        expect(await index.getAllKeys(), [1, 3, 2]);
      });
    });

    group('two_indecies', () {
      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              multiEntry: true);
          objectStore.createIndex(testNameIndex2, testNameField2, unique: true);
        }

        db = await idbFactory!
            .open(dbName, version: 1, onUpgradeNeeded: onUpgradeNeeded);
        dbCreateTransaction();
      }

      tearDown(dbTearDown);

      test('store_properties', () async {
        await dbSetUp();
        expect(objectStore.indexNames, [testNameIndex, testNameIndex2]);
      });

      test('properties', () async {
        await dbSetUp();
        var index = objectStore.index(testNameIndex);
        expect(index.name, testNameIndex);
        expect(index.keyPath, testNameField);

        // multiEntry not supported on ie
        if (!ctx.isIdbIe) {
          expect(index.multiEntry, true);
        }
        expect(index.unique, false);

        index = objectStore.index(testNameIndex2);
        expect(index.name, testNameIndex2);
        expect(index.keyPath, testNameField2);
        if (!ctx.isIdbIe) {
          expect(index.multiEntry, false);
        }
        expect(index.unique, true);
      });
    });

    group('late_index', () {
      test('create_index', () async {
        await setupDeleteDb();
        db = await idbFactory!.open(dbName, version: 1, onUpgradeNeeded: (e) {
          e.database.createObjectStore(testStoreName, autoIncrement: true);
        });
        dbCreateTransaction();
        var map = {testNameField: 1234};
        await objectStore.put(map);
        await objectStore.put({'dummy': 'value'});
        db!.close();
        db = await idbFactory.open(dbName, version: 2, onUpgradeNeeded: (e) {
          e.transaction
              .objectStore(testStoreName)
              .createIndex(testNameIndex, testNameField);
        });
        dbCreateTransaction();
        var index = objectStore.index(testNameIndex);
        expect(await index.get(1234), map);
        expect(await index.count(), 1);
      });
    });

    // not working in memory since not persistent
    if (!ctx.isInMemory) {
      group('create index and re-open', () {
        var index = 0;

        Future testIndex(IdbIndexMeta indexMeta) async {
          try {
            final dbName = '$dbTestName-${++index}';
            await idbFactory!.deleteDatabase(dbName);
            final storeMeta = idbSimpleObjectStoreMeta.clone();
            storeMeta.putIndex(indexMeta);
            var db = await setUpSimpleStore(idbFactory,
                meta: storeMeta, dbName: dbName);
            db.close();
            db = await idbFactory.open(dbName);

            final transaction = db.transaction(storeMeta.name, idbModeReadOnly);
            final objectStore = transaction.objectStore(storeMeta.name);
            final storeIndex = objectStore.index(indexMeta.name!);
            var readMeta = IdbIndexMeta.fromIndex(storeIndex);

            // multi entry not supported on ie
            if (ctx.isIdbIe) {
              readMeta = IdbIndexMeta(readMeta.name, readMeta.keyPath,
                  readMeta.unique, indexMeta.multiEntry);
            }
            expect(readMeta, indexMeta);
          } finally {
            db!.close();
          }
        }

        test('all', () async {
          dbTestName = ctx.dbName;

          for (final indexMeta in idbIndexMetas) {
            await testIndex(indexMeta);
          }
        });

        test('one', () async {
          await testIndex(idbIndexMeta6);
        });

        /*
        test('index key path array, multiEntryone', () async {
          try {
            await testIndex(idbIndexMeta7);
            fail('should fail');
          } catch (e) {
            expect(e, isNot(const TypeMatcher<TestFailure>()));
            print(e);
          }
        });
         */
      });
    }

    group('one index array not unique', () {
      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          var db = e.database;
          var objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(
              testNameIndex, [testNameField, testNameField2],
              unique: false);
        }

        db = await idbFactory!
            .open(dbName, version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(dbTearDown);

      test('add_twice_same_key', () async {
        await dbSetUp();
        dbCreateTransaction();
        var value1 = {testNameField: 'test1', testNameField2: 456};
        var index = objectStore.index(testNameIndex);
        var key1 = await objectStore.add(value1);
        await objectStore.add(value1);
        index = objectStore.index(testNameIndex);
        var count = await index.count(KeyRange.only(['test1', 456]));
        expect(count, 2);
        count = await index.count(['test1', 456]);
        expect(count, 2);

        expect(await index.get(['test1', 456]), value1);
        expect(await index.getKey(['test1', 456]), key1);

        expect(await index.get(['test1', 4567]), isNull);
        expect(await index.getKey(['test1', 4567]), isNull);
      });

      test('getKey_boolean', () async {
        await dbSetUp();
        dbCreateTransaction();
        var index = objectStore.index(testNameIndex);
        try {
          await index.getKey(true);
          fail('error');
        } on DatabaseError catch (e) {
          expect(e, isNotNull);
        }
      });

      test('getAll', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value1 = {testNameField: 'test1', testNameField2: 456};
        final value2 = {testNameField: 'test2'};
        final value3 = {testNameField: 'test1', testNameField2: 456};
        final value4 = {testNameField: 'test1', testNameField2: 123};
        final value5 = {testNameField: 'test1', testNameField2: 789};

        final index = objectStore.index(testNameIndex);
        expect(await index.getAll(), isEmpty);
        expect(await index.getAll(null, 1), isEmpty);
        expect(await index.getAll(1, 1), isEmpty);
        expect(await index.getAllKeys(), isEmpty);
        expect(await index.getAllKeys(null, 1), isEmpty);
        expect(await index.getAllKeys(1, 1), isEmpty);
        var key = await objectStore.put(value1, 1);
        expect(key, 1);
        key = await objectStore.add(value2, 2);
        expect(key, 2);
        await objectStore.add(value3, 3);
        await objectStore.add(value4, 4);
        await objectStore.add(value5, 5);

        expect(await index.getAll('test1'), isEmpty); // Bad key
        expect(await index.getAll(['test1', 456]), [
          {testNameField: 'test1', testNameField2: 456},
          {testNameField: 'test1', testNameField2: 456}
        ]);
        expect(await index.getAllKeys('test1'), isEmpty);
        // Bad key
        expect(await index.getAllKeys(['test1', 456]), [1, 3]);
        expect(await index.getAll(['test1', 456], 1), [
          {testNameField: 'test1', testNameField2: 456},
        ]);
        expect(await index.getAllKeys(['test1', 456], 1), [1]);
        expect(await index.getAll(), [
          {'name': 'test1', 'name_2': 123},
          {'name': 'test1', 'name_2': 456},
          {'name': 'test1', 'name_2': 456},
          {'name': 'test1', 'name_2': 789}
        ]);
        expect(await index.getAllKeys(), [4, 1, 3, 5]);

        expect(
            await index
                .getAllKeys(KeyRange.bound(['test1', 456], ['test1', 790])),
            [1, 3, 5]);
        expect(
            await index.getAllKeys(
                KeyRange.bound(['test1', 456], ['test1', 790]), 2),
            [1, 3]);
        expect(
            await index.getAll(KeyRange.bound(['test1', 456], ['test1', 790])),
            [
              {'name': 'test1', 'name_2': 456},
              {'name': 'test1', 'name_2': 456},
              {'name': 'test1', 'name_2': 789}
            ]);
        expect(
            await index.getAll(
                KeyRange.bound(['test1', 456], ['test1', 790]), 2),
            [
              {'name': 'test1', 'name_2': 456},
              {'name': 'test1', 'name_2': 456},
            ]);
      });
//
//      solo_test('add_twice_same_key', () {
//        Map value1 = {
//          NAME_FIELD: 'test1'
//        };
//
//        Index index = objectStore.index(NAME_INDEX);
//        objectStore.add(value1);
//        objectStore.add(value1);
//        return transaction.completed.then((_) {
////            // create new transaction;
//          dbCreateTransaction();
//          index = objectStore.index(NAME_INDEX);
//          return index.count(new KeyRange.only('test1')).then((int count) {
//            expect(count == 2, isTrue);
//          });
//          // });
//        });
//      });
    });
    group('other', () {
      // InvalidAccessError: Failed to execute 'createIndex' on 'IDBObjectStore': The keyPath argument was an array and the multiEntry option is true.
      // nvalidAccessError: A parameter or an operation is not supported by the underlying object
    });
  });
}
