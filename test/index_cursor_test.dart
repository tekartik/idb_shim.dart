library index_cursor_test;

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/utils/idb_utils.dart';

import 'idb_test_common.dart';

class TestIdNameRow {
  TestIdNameRow(CursorWithValue cwv) {
    Object value = cwv.value;
    name = (value as Map)[testNameField] as String;
    id = cwv.primaryKey as int;
  }

  int id;
  String name;
}

void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;
  group('index_cursor', () {
    Database db;
    Transaction transaction;
    ObjectStore objectStore;
    Index index;

    // new
    String _dbName;
    // prepare for test
    Future _setupDeleteDb() async {
      _dbName = ctx.dbName;
      await idbFactory.deleteDatabase(_dbName);
    }

    Future add(String name) {
      var obj = {testNameField: name};
      return objectStore.put(obj);
    }

    Future fill3SampleRows() {
      return add('test2').then((_) {
        return add('test1');
      }).then((_) {
        return add('test3');
      });
    }

    // generic tearDown
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

    /*
    Future<List<TestIdNameRow>> cursorToList(Stream<CursorWithValue> stream) {
      var completer = Completer<List<TestIdNameRow>>.sync();
      List<TestIdNameRow> list = List();
      stream.listen((CursorWithValue cwv) {
        list.add(TestIdNameRow(cwv));
      }).onDone(() {
        completer.complete(list);
      });
      return completer.future;
    }
    */

    group('with_null_key', () {
      void _createTransaction() {
        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction.objectStore(testStoreName);
        index = objectStore.index(testNameIndex);
      }

      Future _openDb() async {
        String _dbName = ctx.dbName;
        await idbFactory.deleteDatabase(_dbName);
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      // Don't make this function async, crashes on ie
      Future<List<Map>> getIndexRecords() {
        List<Map> list = [];
        Stream<CursorWithValue> stream = index.openCursor(autoAdvance: true);
        return stream.listen((CursorWithValue cwv) {
          list.add(cwv.value as Map);
        }).asFuture(list);
      }

      // Don't make this function async, crashes on ie
      Future<List<String>> getIndexKeys() {
        List<String> list = [];
        Stream<Cursor> stream = index.openKeyCursor(autoAdvance: true);
        return stream.listen((Cursor c) {
          list.add(c.key as String);
        }).asFuture(list);
      }

      test('one_record', () async {
        await _openDb();
        _createTransaction();
        await objectStore.put({"dummy": 1});

        expect(await getIndexRecords(), []);
        expect(await getIndexKeys(), []);
      });

      test('two_record', () async {
        await _openDb();
        _createTransaction();
        await objectStore.put({"dummy": 1});
        await objectStore.put({"dummy": 2, testNameField: "ok"});
        // must be empy as the key is not specified
        expect(await getIndexRecords(), [
          {"dummy": 2, testNameField: "ok"}
        ]);
        expect(await getIndexKeys(), ["ok"]);
      });

      tearDown(_tearDown);
    });

    group('auto', () {
      void _createTransaction() {
        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction.objectStore(testStoreName);
        index = objectStore.index(testNameIndex);
      }

      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('empty key cursor', () async {
        await _setUp();
        _createTransaction();
        Stream<Cursor> stream = index.openKeyCursor(autoAdvance: true);
        int count = 0;
        Completer completer = Completer();
        stream.listen((Cursor cwv) {
          count++;
        }).onDone(() {
          completer.complete();
        });
        return completer.future.then((_) {
          expect(count, 0);
        });
      });

      test('empty key cursor by key', () async {
        await _setUp();
        _createTransaction();
        Stream<Cursor> stream = index.openKeyCursor(key: 1, autoAdvance: true);
        int count = 0;
        Completer completer = Completer();
        stream.listen((Cursor cwv) {
          count++;
        }).onDone(() {
          completer.complete();
        });
        return completer.future.then((_) {
          expect(count, 0);
        });
      });

      test('empty cursor', () async {
        await _setUp();
        _createTransaction();
        Stream<CursorWithValue> stream = index.openCursor(autoAdvance: true);
        int count = 0;
        Completer completer = Completer();
        stream.listen((CursorWithValue cwv) {
          count++;
        }).onDone(() {
          completer.complete();
        });
        return completer.future.then((_) {
          expect(count, 0);
        });
      });

      test('empty cursor by key', () async {
        await _setUp();
        _createTransaction();
        Stream<CursorWithValue> stream =
            index.openCursor(key: 1, autoAdvance: true);
        int count = 0;
        Completer completer = Completer();
        stream.listen((CursorWithValue cwv) {
          count++;
        }).onDone(() {
          completer.complete();
        });
        return completer.future.then((_) {
          expect(count, 0);
        });
      });

      test('one item key cursor', () async {
        await _setUp();
        _createTransaction();
        return add("test1").then((_) {
          Stream<Cursor> stream = index.openKeyCursor(autoAdvance: true);
          int count = 0;
          Completer completer = Completer();
          stream.listen((Cursor cursor) {
            // no value here
            expect(cursor is CursorWithValue, isFalse);
            expect(cursor.key, "test1");
            count++;
          }).onDone(() {
            completer.complete();
          });
          return completer.future.then((_) {
            expect(count, 1);
          });
        });
      });

      test('one item cursor', () async {
        await _setUp();
        _createTransaction();
        return add("test1").then((_) {
          Stream<CursorWithValue> stream = index.openCursor(autoAdvance: true);
          int count = 0;
          Completer completer = Completer();
          stream.listen((CursorWithValue cwv) {
            expect((cwv.value as Map)[testNameField], "test1");
            expect(cwv.key, "test1");
            count++;
          }).onDone(() {
            completer.complete();
          });
          return completer.future.then((_) {
            expect(count, 1);
          });
        });
      });

      test('index get 1', () async {
        await _setUp();
        _createTransaction();
        return add("test1").then((key) {
          return index.get("test1").then((value) {
            expect(value[testNameField], "test1");
          });
        });
      });

      test('cursor non-auto', () async {
        await _setUp();
        _createTransaction();
        return add("test1").then((key) {
          int count = 0;
          // non auto to control advance
          return index
              .openCursor(autoAdvance: false)
              .listen((CursorWithValue cwv) {
                expect(cwv.value, {testNameField: "test1"});
                expect(cwv.key, "test1");
                expect(cwv.primaryKey, key);
                count++;
                cwv.next();
              })
              .asFuture()
              .then((_) {
                expect(count, 1);
              });
        });
      });

      test('cursor none auto delete 1', () async {
        await _setUp();
        _createTransaction();
        return add("test1").then((key) {
          // non auto to control advance
          return index
              .openCursor(autoAdvance: false)
              .listen((CursorWithValue cwv) {
                cwv.delete().then((_) {
                  cwv.next();
                });
              })
              .asFuture()
              .then((_) {
                return transaction.completed.then((_) {
                  transaction = db.transaction(testStoreName, idbModeReadWrite);
                  objectStore = transaction.objectStore(testStoreName);
                  index = objectStore.index(testNameIndex);
                  return index.get(key).then((value) {
                    expect(value, isNull);
                  });
                });
              });
        });
      });

      test('cursor none auto update 1', () async {
        await _setUp();
        _createTransaction();
        return add("test1").then((key) {
          Map map;
          // non auto to control advance
          return index
              .openCursor(autoAdvance: false)
              .listen((CursorWithValue cwv) {
                map = Map.from(cwv.value as Map);
                map["other"] = "too";
                cwv.update(map).then((_) {
                  cwv.next();
                });
              })
              .asFuture()
              .then((_) {
                return transaction.completed.then((_) {
                  transaction = db.transaction(testStoreName, idbModeReadWrite);
                  objectStore = transaction.objectStore(testStoreName);
                  index = objectStore.index(testNameIndex);
                  return index.get("test1").then((value) {
                    expect(value, map);
                  });
                });
              });
        });
      });
      test('3 item cursor', () async {
        await _setUp();
        _createTransaction();
        return fill3SampleRows().then((_) {
          return cursorToList(index.openCursor(autoAdvance: true)).then((list) {
            expect(list[0].value['name'], equals('test1'));
            expect(list[0].primaryKey, equals(2));
            expect(list[1].value['name'], equals('test2'));
            expect(list[2].value['name'], equals('test3'));
            expect(list[2].primaryKey, equals(3));
            expect(list.length, 3);

            return cursorToList(index.openCursor(
                    range: KeyRange.bound('test2', 'test3'), autoAdvance: true))
                .then((list) {
              expect(list.length, 2);
              expect(list[0].value['name'], equals('test2'));
              expect(list[0].primaryKey, equals(1));
              expect(list[1].value['name'], equals('test3'));
              expect(list[1].primaryKey, equals(3));

              return cursorToList(
                      index.openCursor(key: 'test1', autoAdvance: true))
                  .then((list) {
                expect(list.length, 1);
                expect(list[0].value['name'], equals('test1'));
                expect(list[0].primaryKey, equals(2));

                //return transaction.completed;
              });
            });
          });
        });
      });
    });

    group('multiple', () {
      Index nameIndex;
      Index valueIndex;

      void _createTransaction() {
        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction.objectStore(testStoreName);
        nameIndex = objectStore.index(testNameIndex);
        valueIndex = objectStore.index(testValueIndex);
      }

      Future _setUp() async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField);
          objectStore.createIndex(testValueIndex, testValueField);
        }

        return idbFactory
            .open(_dbName, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          db = database;
          return db;
        });
      }

      tearDown(_tearDown);

      test('add and read', () async {
        await _setUp();
        _createTransaction();
        Future<List<int>> getKeys(Stream<Cursor> stream) {
          List<int> keys = [];
          return stream
              .listen((Cursor cursor) {
                keys.add(cursor.primaryKey as int);
              })
              .asFuture()
              .then((_) {
                return keys;
              });
        }

        Future add(String name, int value) {
          var obj = {testNameField: name, testValueField: value};
          return objectStore.put(obj);
        }

        int key1, key2, key3;
        // order should be key1, key3, key2 for name
        // order should be key2, key1, key3 for value
        key1 = await add("a", 2) as int;
        key2 = await add("c", 1) as int;
        key3 = await add("b", 3) as int;

        Stream<Cursor> stream = nameIndex.openKeyCursor(autoAdvance: true);
        expect(await getKeys(stream), [key1, key3, key2]);

        stream = valueIndex.openKeyCursor(autoAdvance: true);
        expect(await getKeys(stream), [key2, key1, key3]);

        stream = valueIndex.openKeyCursor(
            range: KeyRange.lowerBound(2), autoAdvance: true);
        expect(await getKeys(stream), [key1, key3]);

        stream = valueIndex.openKeyCursor(
            range: KeyRange.upperBound(2, true), autoAdvance: true);
        expect(await getKeys(stream), [key2]);
      });
    });

    group('keyPath', () async {
      // new
      String _dbName;
      // prepare for test
      Future _setupDeleteDb() async {
        _dbName = ctx.dbName;
        await idbFactory.deleteDatabase(_dbName);
      }

      test('multi', () async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          var db = e.database;
          var store = db.createObjectStore(testStoreName, autoIncrement: true);
          var index = store.createIndex('test', ['year', 'name']);
          expect(index.keyPath, ['year', 'name']);
        }

        var db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        Transaction transaction;
        ObjectStore objectStore;

        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction.objectStore(testStoreName);
        var index = objectStore.index('test');
        int record1Key =
            await objectStore.put({'year': 2018, 'name': 'John'}) as int;
        int record2Key =
            await objectStore.put({'year': 2018, 'name': 'Jack'}) as int;
        int record3Key =
            await objectStore.put({'year': 2017, 'name': 'John'}) as int;
        /*int record4Key = */
        await objectStore.put({'name': 'John'});
        expect(index.keyPath, ['year', 'name']);
        expect(await index.getKey([2018, 'Jack']), record2Key);
        expect(await index.getKey([2018, 'John']), record1Key);
        expect(await index.getKey([2017, 'Jack']), isNull);
        expect(await index.get([2018, 'Jack']), {'year': 2018, 'name': 'Jack'});
        var list = await cursorToList(index.openCursor(autoAdvance: true));

        expect(list.length, 3);
        expect(list[0].value, {'year': 2017, 'name': 'John'});
        expect(list[0].primaryKey, record3Key);
        expect(list[0].key, [2017, 'John']);
        expect(list[2].key, [2018, 'John']);

        Future terminateTransaction() async {
          await transaction.completed;
        }

        void initTransaction() {
          transaction = db.transaction(testStoreName, idbModeReadWrite);
          objectStore = transaction.objectStore(testStoreName);
          index = objectStore.index('test');
        }

        Future reinitTransaction() async {
          await terminateTransaction();
          initTransaction();
        }

        await reinitTransaction();

        list = await cursorToList(index.openCursor(
            range: KeyRange.bound([2018, 'Jack'], [2018, 'John']),
            autoAdvance: true));
        expect(list.length, 2);
        expect(list[0].primaryKey, record2Key);
        expect(list[1].primaryKey, record1Key);

        await reinitTransaction();

        var keyList =
            await keyCursorToList(index.openCursor(autoAdvance: true));
        // devPrint(keyList);
        expect(keyList.length, 3); // not the 4th one
        expect(keyList[0].key, [2017, 'John']);
        expect(keyList[0].primaryKey, record3Key);
        // devPrint(keyList);

        await reinitTransaction();

        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction.objectStore(testStoreName);
        index = objectStore.index('test');

        list = await cursorToList(index.openCursor(
            range: KeyRange.upperBound([2018, 'Jack'], true),
            autoAdvance: true));

        expect(list.length, 1);
        expect(list[0].primaryKey, record3Key);
        expect(list[0].key, [2017, 'John']);

        await transaction.completed;

        /* not valid on native
        // with null
        await reinitTransaction();
        list = await cursorToList(index.openCursor(
            range: KeyRange.bound([2018, null], [2018, null]),
            autoAdvance: true));
        expect(list.length, 2);
        expect(list[0].primaryKey, record2Key);
        expect(list[1].primaryKey, record1Key);
        */

        db.close();
      });
    },
        // keyPath as array not supported on IE
        skip: ctx.isIdbEdge || ctx.isIdbIe);
  });
}
