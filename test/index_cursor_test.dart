library index_cursor_test;

import 'dart:async';
import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';

// so that this can be run directly
void main() => defineTests(idbTestMemoryFactory);

class TestIdNameRow {
  TestIdNameRow(CursorWithValue cwv) {
    Object value = cwv.value;
    name = (value as Map)[NAME_FIELD];
    id = cwv.primaryKey;
  }
  int id;
  String name;
}

//// so that this can be run directly
//void main() {
//  testMain(new IdbMemoryFactory());
//}
void defineTests(IdbFactory idbFactory) {
  group('index_cursor', () {
    Database db;
    Transaction transaction;
    ObjectStore objectStore;
    Index index;

    Future add(String name) {
      var obj = {NAME_FIELD: name};
      return objectStore.put(obj);
    }

    Future fill3SampleRows() {
      return add('test2').then((_) {
        return add('test1');
      }).then((_) {
        return add('test3');
      });
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

    group('auto', () {
      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore =
                db.createObjectStore(STORE_NAME, autoIncrement: true);
            objectStore.createIndex(NAME_INDEX, NAME_FIELD);
          }
          return idbFactory
              .open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase)
              .then((Database database) {
            db = database;
            transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
            objectStore = transaction.objectStore(STORE_NAME);
            index = objectStore.index(NAME_INDEX);
            return db;
          });
        });
      });

      tearDown(() {
        return transaction.completed.then((_) {
          db.close();
        });
      });

      test('empty key cursor', () {
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
        return add("test1").then((_) {
          Stream<CursorWithValue> stream = index.openCursor(autoAdvance: true);
          int count = 0;
          Completer completer = new Completer();
          stream.listen((CursorWithValue cwv) {
            expect((cwv.value as Map)[NAME_FIELD], "test1");
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
        return add("test1").then((key) {
          return index.get("test1").then((value) {
            expect(value[NAME_FIELD], "test1");
          });
        });
      });

      test('cursor non-auto', () {
        return add("test1").then((key) {
          int count = 0;
          // non auto to control advance
          return index
              .openCursor(autoAdvance: false)
              .listen((CursorWithValue cwv) {
            expect(cwv.value, {NAME_FIELD: "test1"});
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
              transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
              objectStore = transaction.objectStore(STORE_NAME);
              index = objectStore.index(NAME_INDEX);
              return index.get(key).then((value) {
                expect(value, isNull);
              });
            });
          });
        });
      });

      test('cursor none auto update 1', () {
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
              transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
              objectStore = transaction.objectStore(STORE_NAME);
              index = objectStore.index(NAME_INDEX);
              return index.get("test1").then((value) {
                expect(value, map);
              });
            });
          });
        });
      });
      test('3 item cursor', () {
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
      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore =
                db.createObjectStore(STORE_NAME, autoIncrement: true);
            objectStore.createIndex(NAME_INDEX, NAME_FIELD);
            objectStore.createIndex(VALUE_INDEX, VALUE_FIELD);
          }
          return idbFactory
              .open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase)
              .then((Database database) {
            db = database;
            transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
            objectStore = transaction.objectStore(STORE_NAME);
            nameIndex = objectStore.index(NAME_INDEX);
            valueIndex = objectStore.index(VALUE_INDEX);
            return db;
          });
        });
      });

      tearDown(() {
        return transaction.completed.then((_) {
          db.close();
        });
      });

      test('add and read', () {
        Future<List<int>> getKeys(Stream<Cursor> stream) {
          List<int> keys = [];
          return stream.listen((Cursor cursor) {
            keys.add(cursor.primaryKey);
          }).asFuture().then((_) {
            return keys;
          });
        }
        Future add(String name, int value) {
          var obj = {NAME_FIELD: name, VALUE_FIELD: value};
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
