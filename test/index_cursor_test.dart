library index_cursor_test;

import 'dart:async';
import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';

class TestIdNameRow {
  TestIdNameRow(CursorWithValue cwv) {
    Object value = cwv.value;
    name = (value as Map)[testNameField];
    id = cwv.primaryKey;
  }
  int id;
  String name;
}

main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;
  group('index_cursor', () {
    Database db;
    Transaction transaction;
    ObjectStore objectStore;
    Index index;

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

    Future<List<TestIdNameRow>> cursorToList(Stream<CursorWithValue> stream) {
      Completer completer = new Completer.sync();
      List<TestIdNameRow> list = new List();
      stream.listen((CursorWithValue cwv) {
        list.add(new TestIdNameRow(cwv));
      }).onDone(() {
        completer.complete(list);
      });
      return completer.future;
    }

    group('with_null_key', () {
      _createTransaction() {
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
          list.add(cwv.value);
        }).asFuture(list);
      }

      // Don't make this function async, crashes on ie
      Future<List<String>> getIndexKeys() {
        List<String> list = [];
        Stream<Cursor> stream = index.openKeyCursor(autoAdvance: true);
        return stream.listen((Cursor c) {
          list.add(c.key);
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
      _createTransaction() {
        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction.objectStore(testStoreName);
        index = objectStore.index(testNameIndex);
      }

      setUp(() {
        return idbFactory.deleteDatabase(testDbName).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore =
                db.createObjectStore(testStoreName, autoIncrement: true);
            objectStore.createIndex(testNameIndex, testNameField);
          }
          return idbFactory
              .open(testDbName,
                  version: 1, onUpgradeNeeded: _initializeDatabase)
              .then((Database database) {
            db = database;
            return db;
          });
        });
      });

      tearDown(_tearDown);

      test('empty key cursor', () {
        _createTransaction();
        Stream<Cursor> stream = index.openKeyCursor(autoAdvance: true);
        int count = 0;
        Completer completer = new Completer();
        stream.listen((Cursor cwv) {
          count++;
        }).onDone(() {
          completer.complete();
        });
        return completer.future.then((_) {
          expect(count, 0);
        });
      });

      test('empty key cursor by key', () {
        _createTransaction();
        Stream<Cursor> stream = index.openKeyCursor(key: 1, autoAdvance: true);
        int count = 0;
        Completer completer = new Completer();
        stream.listen((Cursor cwv) {
          count++;
        }).onDone(() {
          completer.complete();
        });
        return completer.future.then((_) {
          expect(count, 0);
        });
      });

      test('empty cursor', () {
        _createTransaction();
        Stream<CursorWithValue> stream = index.openCursor(autoAdvance: true);
        int count = 0;
        Completer completer = new Completer();
        stream.listen((CursorWithValue cwv) {
          count++;
        }).onDone(() {
          completer.complete();
        });
        return completer.future.then((_) {
          expect(count, 0);
        });
      });

      test('empty cursor by key', () {
        _createTransaction();
        Stream<CursorWithValue> stream =
            index.openCursor(key: 1, autoAdvance: true);
        int count = 0;
        Completer completer = new Completer();
        stream.listen((CursorWithValue cwv) {
          count++;
        }).onDone(() {
          completer.complete();
        });
        return completer.future.then((_) {
          expect(count, 0);
        });
      });

      test('one item key cursor', () {
        _createTransaction();
        return add("test1").then((_) {
          Stream<Cursor> stream = index.openKeyCursor(autoAdvance: true);
          int count = 0;
          Completer completer = new Completer();
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

      test('one item cursor', () {
        _createTransaction();
        return add("test1").then((_) {
          Stream<CursorWithValue> stream = index.openCursor(autoAdvance: true);
          int count = 0;
          Completer completer = new Completer();
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

      test('index get 1', () {
        _createTransaction();
        return add("test1").then((key) {
          return index.get("test1").then((value) {
            expect(value[testNameField], "test1");
          });
        });
      });

      test('cursor non-auto', () {
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
          }).asFuture().then((_) {
            expect(count, 1);
          });
        });
      });

      test('cursor none auto delete 1', () {
        _createTransaction();
        return add("test1").then((key) {
          // non auto to control advance
          return index
              .openCursor(autoAdvance: false)
              .listen((CursorWithValue cwv) {
            cwv.delete().then((_) {
              cwv.next();
            });
          }).asFuture().then((_) {
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

      test('cursor none auto update 1', () {
        _createTransaction();
        return add("test1").then((key) {
          Map map;
          // non auto to control advance
          return index
              .openCursor(autoAdvance: false)
              .listen((CursorWithValue cwv) {
            map = new Map.from(cwv.value);
            map["other"] = "too";
            cwv.update(map).then((_) {
              cwv.next();
            });
          }).asFuture().then((_) {
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
      test('3 item cursor', () {
        _createTransaction();
        return fill3SampleRows().then((_) {
          return cursorToList(index.openCursor(autoAdvance: true)).then((list) {
            expect(list[0].name, equals('test1'));
            expect(list[0].id, equals(2));
            expect(list[1].name, equals('test2'));
            expect(list[2].name, equals('test3'));
            expect(list[2].id, equals(3));
            expect(list.length, 3);

            return cursorToList(index.openCursor(
                range: new KeyRange.bound('test2', 'test3'),
                autoAdvance: true)).then((list) {
              expect(list.length, 2);
              expect(list[0].name, equals('test2'));
              expect(list[0].id, equals(1));
              expect(list[1].name, equals('test3'));
              expect(list[1].id, equals(3));

              return cursorToList(
                      index.openCursor(key: 'test1', autoAdvance: true))
                  .then((list) {
                expect(list.length, 1);
                expect(list[0].name, equals('test1'));
                expect(list[0].id, equals(2));

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

      _createTransaction() {
        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction.objectStore(testStoreName);
        nameIndex = objectStore.index(testNameIndex);
        valueIndex = objectStore.index(testValueIndex);
      }
      setUp(() {
        return idbFactory.deleteDatabase(testDbName).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore =
                db.createObjectStore(testStoreName, autoIncrement: true);
            objectStore.createIndex(testNameIndex, testNameField);
            objectStore.createIndex(testValueIndex, testValueField);
          }
          return idbFactory
              .open(testDbName,
                  version: 1, onUpgradeNeeded: _initializeDatabase)
              .then((Database database) {
            db = database;
            return db;
          });
        });
      });

      tearDown(_tearDown);

      test('add and read', () {
        _createTransaction();
        Future<List<int>> getKeys(Stream<Cursor> stream) {
          List<int> keys = [];
          return stream.listen((Cursor cursor) {
            keys.add(cursor.primaryKey);
          }).asFuture().then((_) {
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
        return add("a", 2).then((key) {
          key1 = key;
          return add("c", 1);
        }).then((key) {
          key2 = key;
          return add("b", 3);
        }).then((key) {
          key3 = key;
          Stream<Cursor> stream = nameIndex.openKeyCursor(autoAdvance: true);
          return getKeys(stream).then((result) {
            expect(result, [key1, key3, key2]);
          });
        }).then((_) {
          Stream<Cursor> stream = valueIndex.openKeyCursor(autoAdvance: true);
          return getKeys(stream).then((result) {
            expect(result, [key2, key1, key3]);
          });
        }).then((_) {
          Stream<Cursor> stream = valueIndex.openKeyCursor(
              range: new KeyRange.lowerBound(2), autoAdvance: true);
          return getKeys(stream).then((result) {
            expect(result, [key1, key3]);
          });
        }).then((_) {
          Stream<Cursor> stream = valueIndex.openKeyCursor(
              range: new KeyRange.upperBound(2, true), autoAdvance: true);
          return getKeys(stream).then((result) {
            expect(result, [key2]);
          });
        });
      });
    });
  });
}
