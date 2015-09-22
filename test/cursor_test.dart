library cursor_test;

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

// so that this can be run directly
void main() => defineTests(idbTestMemoryFactory);

void defineTests(IdbFactory idbFactory) {
  group('cursor', () {
    Database db;
    Transaction transaction;
    ObjectStore objectStore;

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

//    Future<List<TestIdNameRow>> _cursorToList(Stream<CursorWithValue> stream) {
//      Completer completer = new Completer.sync();
//      List<TestIdNameRow> list = new List();
//      stream.listen((CursorWithValue cwv) {
//        list.add(new TestIdNameRow(cwv));
//      }).onDone(() {
//        completer.complete(list);
//      });
//      return completer.future;
//    }

    Future<List<TestIdNameRow>> cursorToList(Stream<CursorWithValue> stream) {
      List<TestIdNameRow> list = new List();
      return stream.listen((CursorWithValue cwv) {
        list.add(new TestIdNameRow(cwv));
      }).asFuture(list);
    }

    Future<List<TestIdNameRow>> manualCursorToList(
        Stream<CursorWithValue> stream) {
      List<TestIdNameRow> list = new List();
      return stream.listen((CursorWithValue cwv) {
        list.add(new TestIdNameRow(cwv));
        cwv.next();
      }).asFuture(list);
    }

    group('auto', () {
      setUp(() {
        return idbFactory.deleteDatabase(testDbName).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            //ObjectStore objectStore =
            db.createObjectStore(testStoreName, autoIncrement: true);
          }
          return idbFactory
              .open(testDbName,
                  version: 1, onUpgradeNeeded: _initializeDatabase)
              .then((Database database) {
            db = database;
            transaction = db.transaction(testStoreName, idbModeReadWrite);
            objectStore = transaction.objectStore(testStoreName);
            // must return something not null...
            return db;
          });
        });
      });

      tearDown(() {
        // This sometimes block in dart2js
        //return transaction.completed.then((_) {
        db.close();
        //});
      });

      test('empty cursor', () {
        Stream<CursorWithValue> stream =
            objectStore.openCursor(autoAdvance: true);
        int count = 0;
        return stream.listen((CursorWithValue cwv) {
          count++;
        }).asFuture().then((_) {
          expect(count, 0);
        });
      });

      test('one item cursor', () {
        return add("test1").then((_) {
          Stream<CursorWithValue> stream =
              objectStore.openCursor(autoAdvance: true);
          int count = 0;
          Completer completer = new Completer();
          stream.listen((CursorWithValue cwv) {
            expect((cwv.value as Map)[testNameField], "test1");
            count++;
          }).onDone(() {
            completer.complete();
          });
          return completer.future.then((_) {
            expect(count, 1);
          });
        });
      });

      test('openCursor_read_2_row', () async {
        await fill3SampleRows();

        int count = 0;
        int limit = 2;
        objectStore
            .openCursor(autoAdvance: false)
            .listen((CursorWithValue cwv) {
          if (++count < limit) {
            cwv.next();
          }
        });
        await transaction.completed;
        expect(count, limit);
      });

      test('openCursor no auto advance timeout', () {
        return fill3SampleRows().then((_) {
          return objectStore
              .openCursor(autoAdvance: false)
              .listen((CursorWithValue cwv) {}).asFuture().then((_) {
            fail('should not complete');
          }).timeout(new Duration(milliseconds: 500), onTimeout: () {});
        });
      });

      test('openCursor null auto advance timeout', () {
        return fill3SampleRows().then((_) {
          return objectStore
              .openCursor(autoAdvance: null)
              .listen((CursorWithValue cwv) {}).asFuture().then((_) {
            fail('should not complete');
          }).timeout(new Duration(milliseconds: 500), onTimeout: () {});
        });
      });
      test('3 item cursor no auto advance', () {
        return fill3SampleRows().then((_) {
          return manualCursorToList(objectStore.openCursor(autoAdvance: false))
              .then((list) {
            expect(list[0].name, equals('test2'));
            expect(list[0].id, equals(1));
            expect(list[1].name, equals('test1'));
            expect(list[2].name, equals('test3'));
            expect(list[2].id, equals(3));
            expect(list.length, 3);
          });
        });
      });
      test('3 item cursor', () {
        return fill3SampleRows().then((_) {
          return cursorToList(objectStore.openCursor(autoAdvance: true))
              .then((list) {
            expect(list[0].name, equals('test2'));
            expect(list[0].id, equals(1));
            expect(list[1].name, equals('test1'));
            expect(list[2].name, equals('test3'));
            expect(list[2].id, equals(3));
            expect(list.length, 3);

            return cursorToList(objectStore.openCursor(
                range: new KeyRange.bound(2, 3),
                autoAdvance: true)).then((list) {
              expect(list.length, 2);
              expect(list[0].name, equals('test1'));
              expect(list[0].id, equals(2));
              expect(list[1].name, equals('test3'));
              expect(list[1].id, equals(3));

              return cursorToList(objectStore.openCursor(
                  range: new KeyRange.bound(1, 3, true, true),
                  autoAdvance: true)).then((list) {
                expect(list.length, 1);
                expect(list[0].name, equals('test1'));
                expect(list[0].id, equals(2));

                return cursorToList(objectStore.openCursor(
                    range: new KeyRange.lowerBound(2),
                    autoAdvance: true)).then((list) {
                  expect(list.length, 2);
                  expect(list[0].name, equals('test1'));
                  expect(list[0].id, equals(2));
                  expect(list[1].name, equals('test3'));
                  expect(list[1].id, equals(3));

                  return cursorToList(objectStore.openCursor(
                      range: new KeyRange.upperBound(2, true),
                      autoAdvance: true)).then((list) {
                    expect(list.length, 1);
                    expect(list[0].name, equals('test2'));
                    expect(list[0].id, equals(1));

                    return cursorToList(
                            objectStore.openCursor(key: 2, autoAdvance: true))
                        .then((list) {
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
      });
    });
  });
}
