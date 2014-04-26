library index_cursor_test;

import 'dart:async';
import 'package:unittest/unittest.dart';
import 'package:tekartik_idb/idb_client.dart';
import 'idb_test_common.dart';

class TestIdNameRow {
  TestIdNameRow(CursorWithValue cwv) {
    Object value = cwv.value;
    name = (value as Map)[NAME_FIELD];
    id = cwv.primaryKey;
  }
  int id;
  String name;
}

void testMain(IdbFactory idbFactory) {

  group('index cursor', () {

    Database db;
    Transaction transaction;
    ObjectStore objectStore;
    Index index;

    Future add(String name) {
      var obj = {
        NAME_FIELD: name
      };
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
            ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
            Index index = objectStore.createIndex(NAME_INDEX, NAME_FIELD);
          }
          return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
            db = database;
            transaction = db.transaction(STORE_NAME, MODE_READ_WRITE);
            objectStore = transaction.objectStore(STORE_NAME);
            index = objectStore.index(NAME_INDEX);
            return db;

          });
        });
      });

      tearDown(() {
        //return transaction.completed.then((_) {
        db.close();
        //});
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

      test('3 item cursor', () {
        return fill3SampleRows().then((_) {
          return cursorToList(index.openCursor(autoAdvance: true)).then((list) {
            expect(list[0].name, equals('test1'));
            expect(list[0].id, equals(2));
            expect(list[1].name, equals('test2'));
            expect(list[2].name, equals('test3'));
            expect(list[2].id, equals(3));
            expect(list.length, 3);

            return cursorToList(index.openCursor(range: new KeyRange.bound('test2', 'test3'), autoAdvance: true)).then((list) {
              expect(list.length, 2);
              expect(list[0].name, equals('test2'));
              expect(list[0].id, equals(1));
              expect(list[1].name, equals('test3'));
              expect(list[1].id, equals(3));

              return cursorToList(index.openCursor(key: 'test1', autoAdvance: true)).then((list) {
                expect(list.length, 1);
                expect(list[0].name, equals('test1'));
                expect(list[0].id, equals(2));

                return transaction.completed;
              });
            });
          });



        });
      });
    });
  });
}
