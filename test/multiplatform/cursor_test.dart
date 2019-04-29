library cursor_test;

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:pedantic/pedantic.dart';

import '../idb_test_common.dart';

class TestIdNameRow {
  TestIdNameRow(CursorWithValue cwv) {
    Object value = cwv.value;
    name = (value as Map)[testNameField] as String;
    id = cwv.primaryKey as int;
  }

  int id;
  String name;
}

// so that this can be run directly
void main() {
  // devPrint('CURSOR');
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;

  Database db;
  Transaction transaction;
  ObjectStore objectStore;

  String _dbName;

  void _createTransaction() {
    transaction = db.transaction(testStoreName, idbModeReadWrite);
    objectStore = transaction.objectStore(testStoreName);
  }

  // prepare for test
  Future _setupDeleteDb() async {
    _dbName = ctx.dbName;
    await idbFactory.deleteDatabase(_dbName);
  }

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

  group('cursor', () {
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
      List<TestIdNameRow> list = [];
      return stream.listen((CursorWithValue cwv) {
        list.add(TestIdNameRow(cwv));
      }).asFuture(list);
    }

    Future<List<TestIdNameRow>> manualCursorToList(
        Stream<CursorWithValue> stream) {
      List<TestIdNameRow> list = [];
      return stream.listen((CursorWithValue cwv) {
        list.add(TestIdNameRow(cwv));
        cwv.next();
      }).asFuture(list);
    }

    group('key_path_with_dot', () {
      const String keyPath = "my.key";

      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore(testStoreName, keyPath: keyPath);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('one item cursor', () async {
        await _setUp();
        _createTransaction();
        var value = {
          'my': {'key': 'test_value'}
        };
        await objectStore.add(value);
        Stream<CursorWithValue> stream =
            objectStore.openCursor(autoAdvance: true, key: 'test_value');
        int count = 0;
        Completer completer = Completer();
        stream.listen((CursorWithValue cwv) {
          expect(cwv.value, value);
          count++;
        }).onDone(() {
          completer.complete();
        });
        await completer.future;
        expect(count, 1);
      });
    });

    group('update', () {
      test('key_path_cursor_update', () async {
        var dbName = 'key_path_cursor_update.db';
        await idbFactory.deleteDatabase(dbName);

        final db = await idbFactory.open(dbName, version: 1,
            onUpgradeNeeded: (VersionChangeEvent change) {
          change.database.createObjectStore('store1', keyPath: 'key');
        });
        try {
          final obj = <String, dynamic>{
            'key': 1,
            'someval': 'lorem',
          };
          final obj2 = <String, dynamic>{
            'key': 1,
            'someval': 'ipsem',
          };
          final t1 = db.transaction('store1', idbModeReadWrite);
          final store1 = t1.objectStore('store1');
          unawaited(store1.put(obj));
          await t1.completed;

          final t2 = db.transaction('store1', idbModeReadWrite);
          final store2 = t2.objectStore('store1');
          unawaited(store2.openCursor().forEach((cv) {
            expect(cv.key, 1);
            expect(cv.primaryKey, 1);
            expect(cv.value, obj);

            cv.update(obj2);
          }));
          await t2.completed;

          final t3 = db.transaction('store1', idbModeReadWrite);
          final store3 = t3.objectStore('store1');
          final ret = await store3.getObject(1);

          expect(ret, equals(obj2));
        } finally {
          db.close();
        }
      });

      test('key_path_auto_cursor_update', () async {
        var dbName = 'key_path_auto_cursor_update.db';
        await idbFactory.deleteDatabase(dbName);

        final db = await idbFactory.open(dbName, version: 1,
            onUpgradeNeeded: (VersionChangeEvent change) {
          change.database
              .createObjectStore('store1', keyPath: 'key', autoIncrement: true);
        });
        try {
          final obj = <String, dynamic>{
            'key': 1,
            'someval': 'lorem',
          };
          final obj2 = <String, dynamic>{
            'key': 1,
            'someval': 'ipsem',
          };
          final t1 = db.transaction('store1', idbModeReadWrite);
          final store1 = t1.objectStore('store1');
          unawaited(store1.put(obj));
          await t1.completed;

          final t2 = db.transaction('store1', idbModeReadWrite);
          final store2 = t2.objectStore('store1');
          unawaited(store2.openCursor().forEach((cv) {
            expect(cv.key, 1);
            expect(cv.primaryKey, 1);
            expect(cv.value, obj);

            cv.update(obj2);
          }));
          await t2.completed;

          final t3 = db.transaction('store1', idbModeReadWrite);
          final store3 = t3.objectStore('store1');
          final ret = await store3.getObject(1);

          expect(ret, equals(obj2));
        } finally {
          db.close();
        }
      });
    });

    group('auto', () {
      tearDown(_tearDown);

      void _createTransaction() {
        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction.objectStore(testStoreName);
      }

      Future _setUp() async {
        await _setupDeleteDb();
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      test('empty cursor', () async {
        await _setUp();
        _createTransaction();
        Stream<CursorWithValue> stream =
            objectStore.openCursor(autoAdvance: true);
        int count = 0;
        return stream
            .listen((CursorWithValue cwv) {
              count++;
            })
            .asFuture()
            .then((_) {
              expect(count, 0);
            });
      });

      test('one item cursor', () async {
        await _setUp();
        _createTransaction();
        return add("test1").then((_) {
          Stream<CursorWithValue> stream =
              objectStore.openCursor(autoAdvance: true);
          int count = 0;
          Completer completer = Completer();
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
        await _setUp();
        _createTransaction();
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
        transaction = null;
        expect(count, limit);
      });

      test('openCursor no auto advance timeout', () async {
        await _setUp();
        _createTransaction();
        return fill3SampleRows().then((_) {
          return objectStore
              .openCursor(autoAdvance: false)
              .listen((CursorWithValue cwv) {})
              .asFuture()
              .then((_) {
            fail('should not complete');
          }).timeout(Duration(milliseconds: 500), onTimeout: () {
            // don't wait on the transaction
            transaction = null;
          });
        });
      });

      test('openCursor null auto advance timeout', () async {
        await _setUp();
        _createTransaction();
        return fill3SampleRows().then((_) {
          return objectStore
              .openCursor(autoAdvance: null)
              .listen((CursorWithValue cwv) {})
              .asFuture()
              .then((_) {
            fail('should not complete');
          }).timeout(Duration(milliseconds: 500), onTimeout: () {
            // don't wait on the transaction
            transaction = null;
          });
        });
      });
      test('3 item cursor no auto advance', () async {
        await _setUp();
        _createTransaction();
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
      test('3 item cursor', () async {
        await _setUp();
        _createTransaction();
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
                    range: KeyRange.bound(2, 3), autoAdvance: true))
                .then((list) {
              expect(list.length, 2);
              expect(list[0].name, equals('test1'));
              expect(list[0].id, equals(2));
              expect(list[1].name, equals('test3'));
              expect(list[1].id, equals(3));

              return cursorToList(objectStore.openCursor(
                      range: KeyRange.bound(1, 3, true, true),
                      autoAdvance: true))
                  .then((list) {
                expect(list.length, 1);
                expect(list[0].name, equals('test1'));
                expect(list[0].id, equals(2));

                return cursorToList(objectStore.openCursor(
                        range: KeyRange.lowerBound(2), autoAdvance: true))
                    .then((list) {
                  expect(list.length, 2);
                  expect(list[0].name, equals('test1'));
                  expect(list[0].id, equals(2));
                  expect(list[1].name, equals('test3'));
                  expect(list[1].id, equals(3));

                  return cursorToList(objectStore.openCursor(
                          range: KeyRange.upperBound(2, true),
                          autoAdvance: true))
                      .then((list) {
                    expect(list.length, 1);
                    expect(list[0].name, equals('test2'));
                    expect(list[0].id, equals(1));

                    return cursorToList(
                            objectStore.openCursor(key: 2, autoAdvance: true))
                        .then((list) {
                      expect(list.length, 1);
                      expect(list[0].name, equals('test1'));
                      expect(list[0].id, equals(2));

                      return transaction.completed.then((_) {
                        transaction = null;
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
  });
}
