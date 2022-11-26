library cursor_test;

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';

class TestIdNameRow {
  TestIdNameRow(CursorWithValue cwv) {
    final value = cwv.value;
    name = (value as Map)[testNameField] as String?;
    id = cwv.primaryKey as int;
  }

  int? id;
  String? name;
}

// so that this can be run directly
void main() {
  // devPrint('CURSOR');
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  Database? db;
  Transaction? transaction;
  late ObjectStore objectStore;

  late String dbName;

  void createTransaction() {
    transaction = db!.transaction(testStoreName, idbModeReadWrite);
    objectStore = transaction!.objectStore(testStoreName);
  }

  // prepare for test
  Future setupDeleteDb() async {
    dbName = ctx.dbName;
    await idbFactory.deleteDatabase(dbName);
  }

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

  group('cursor', () {
    Future add(String name) {
      var obj = {testNameField: name};
      return objectStore.put(obj);
    }

    Future fill3SampleRows() async {
      await add('test2');
      await add('test1');
      await add('test3');
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
      final list = <TestIdNameRow>[];
      return stream.listen((CursorWithValue cwv) {
        list.add(TestIdNameRow(cwv));
      }).asFuture(list);
    }

    Future<List<TestIdNameRow>> manualCursorToList(
        Stream<CursorWithValue> stream) {
      final list = <TestIdNameRow>[];
      return stream.listen((CursorWithValue cwv) {
        list.add(TestIdNameRow(cwv));
        cwv.next();
      }).asFuture(list);
    }

    group('key_path_with_dot', () {
      const keyPath = 'my.key';

      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, keyPath: keyPath);
        }

        db = await idbFactory.open(dbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(dbTearDown);

      test('one item cursor', () async {
        await dbSetUp();
        createTransaction();
        var value = {
          'my': {'key': 'test_value'}
        };
        await objectStore.add(value);
        final stream =
            objectStore.openCursor(autoAdvance: true, key: 'test_value');
        var count = 0;
        final completer = Completer();
        stream.listen((CursorWithValue cwv) {
          expect(cwv.value, value);
          count++;
        }).onDone(() {
          completer.complete();
        });
        await completer.future;
        expect(count, 1);

        // Key cursor
        {
          final stream =
              objectStore.openKeyCursor(autoAdvance: true, key: 'test_value');
          var count = 0;
          await stream.listen((Cursor cursor) {
            expect(cursor, isNot(const TypeMatcher<CursorWithValue>()));
            expect(cursor.key, 'test_value');
            expect(cursor.primaryKey, 'test_value');
            count++;
          }).asFuture();

          expect(count, 1);
        }

        var valueRead = false;

        // Cancel subscription
        {
          final stream =
              objectStore.openCursor(autoAdvance: true, key: 'test_value');

          var subscription = stream.listen((cwv) {
            valueRead = true;
          });
          unawaited(subscription.cancel());
        }

        // Cancel subscription no auto advance
        {
          final stream =
              objectStore.openCursor(autoAdvance: false, key: 'test_value');

          var subscription = stream.listen((cwv) {
            valueRead = true;
          });
          unawaited(subscription.cancel());
        }

        await objectStore
            .openCursor(autoAdvance: true, key: 'test_value')
            .first;
        await objectStore
            .openCursor(autoAdvance: false, key: 'test_value')
            .first;

        await transaction?.completed;
        expect(valueRead, isFalse);
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
          final obj = <String, Object?>{
            'key': 1,
            'someval': 'lorem',
          };
          final obj2 = <String, Object?>{
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
          final obj = <String, Object?>{
            'key': 1,
            'someval': 'lorem',
          };
          final obj2 = <String, Object?>{
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

          final t3 = db.transaction('store1', idbModeReadOnly);
          final store3 = t3.objectStore('store1');
          final ret = await store3.getObject(1);

          expect(ret, equals(obj2));

          // Key cursor
          {
            final t = db.transaction('store1', idbModeReadWrite);
            var store = t.objectStore('store1');
            await store.openKeyCursor().forEach((cursor) async {
              expect(cursor.key, 1);
              expect(cursor.primaryKey, 1);

              /*
              try {
                await cursor.update(obj3);
                fail('should fail - update not supported on key cursor');
              } catch (e) {
                expect(e, isNot(const TypeMatcher<TestFailure>()));
                devPrint('${e.runtimeType}');
              }
               */
              cursor.next();
            });
          }
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
          final obj = <String, Object?>{
            'key': 1,
            'someval': 'lorem',
          };
          final obj2 = <String, Object?>{
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

          final t3 = db.transaction('store1', idbModeReadOnly);
          final store3 = t3.objectStore('store1');
          final ret = await store3.getObject(1);

          expect(ret, equals(obj2));

          // Key cursor
          {
            final t = db.transaction('store1', idbModeReadWrite);
            var store = t.objectStore('store1');
            await store.openKeyCursor().forEach((cursor) async {
              expect(cursor.key, 1);
              expect(cursor.primaryKey, 1);

              /*
              try {
                await cursor.update(obj3);
                fail('should fail - update not supported on key cursor');
              } catch (e) {
                expect(e, isNot(const TypeMatcher<TestFailure>()));
                devPrint('${e.runtimeType}');
              }
               */
              cursor.next();
            });
          }
        } finally {
          db.close();
        }
      });
    });

    group('auto', () {
      tearDown(dbTearDown);

      void dbCreateTransaction() {
        transaction = db!.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction!.objectStore(testStoreName);
      }

      Future dbSetUp() async {
        await setupDeleteDb();
        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory.open(dbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      test('empty cursor', () async {
        await dbSetUp();
        dbCreateTransaction();
        final stream = objectStore.openCursor(autoAdvance: true);
        var count = 0;
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
        await dbSetUp();
        dbCreateTransaction();
        return add('test1').then((_) {
          final stream = objectStore.openCursor(autoAdvance: true);
          var count = 0;
          final completer = Completer();
          stream.listen((CursorWithValue cwv) {
            expect((cwv.value as Map)[testNameField], 'test1');
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
        await dbSetUp();
        dbCreateTransaction();
        await fill3SampleRows();

        var count = 0;
        var limit = 2;
        objectStore
            .openCursor(autoAdvance: false)
            .listen((CursorWithValue cwv) {
          if (++count < limit) {
            cwv.next();
          }
        });
        await transaction!.completed;
        transaction = null;
        expect(count, limit);
      });

      test('openKeyCursor_read_2_row', () async {
        await dbSetUp();
        dbCreateTransaction();
        await fill3SampleRows();

        var count = 0;
        var limit = 2;
        objectStore.openKeyCursor(autoAdvance: false).listen((Cursor cursor) {
          if (++count < limit) {
            cursor.next();
          }
        });
        await transaction!.completed;
        transaction = null;
        expect(count, limit);
      });

      test('openCursor no auto advance timeout', () async {
        await dbSetUp();
        dbCreateTransaction();
        await fill3SampleRows().then((_) async {
          await objectStore
              .openCursor(autoAdvance: false)
              .listen((CursorWithValue cwv) {})
              .asFuture()
              .timeout(const Duration(milliseconds: 500), onTimeout: () {
            // don't wait on the transaction
            transaction = null;
            return null;
          });
          expect(transaction, isNull);
        });
      });

      test('openCursor null auto advance timeout', () async {
        await dbSetUp();
        dbCreateTransaction();
        await fill3SampleRows().then((_) async {
          await objectStore
              .openCursor(autoAdvance: null)
              .listen((CursorWithValue cwv) {})
              .asFuture()
              .timeout(const Duration(milliseconds: 500), onTimeout: () {
            // don't wait on the transaction
            transaction = null;
          });
          expect(transaction, isNull);
        });
      });
      test('3 item cursor no auto advance', () async {
        await dbSetUp();
        dbCreateTransaction();
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
        await dbSetUp();
        dbCreateTransaction();
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

                      return transaction!.completed.then((_) {
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
      test('key args as Range', () async {
        await dbSetUp();
        dbCreateTransaction();
        try {
          await objectStore
              .openCursor(autoAdvance: false, key: KeyRange.only(1))
              .toList();
          fail('should fail');
        } catch (e) {
          // DomException
          // DataError: Failed to execute 'openCursor' on 'IDBObjectStore': The parameter is not a valid key.
          // print(e.runtimeType);
          // print(e);
          expect(e, isNot(const TypeMatcher<TestFailure>()));
        }
      });
    });

    group('issue#42', () {
      Future<Database> getDb() async {
        var dbName = 'key_path_cursor_update_issue48.db';
        await idbFactory.deleteDatabase(dbName);

        return idbFactory.open(dbName, version: 1,
            onUpgradeNeeded: (VersionChangeEvent change) {
          change.database
              .createObjectStore('store', keyPath: 'key', autoIncrement: true);
        });
      }

      Future<Object> insert(Database db, Map<String, Object?> obj) async {
        final t = db.transaction('store', idbModeReadWrite);
        final store = t.objectStore('store');

        final ret = await store.put(obj);
        await t.completed;
        return ret;
      }

      Future<Object> update(Database db, Map<String, Object?> obj) async {
        final t = db.transaction('store', idbModeReadWrite);
        final store = t.objectStore('store');

        final ret = store.openCursor().forEach((cv) {
          cv.update(obj);
        });
        await t.completed;
        return ret;
      }

      Future<Object?> get(Database db, Object? key) {
        final t = db.transaction('store', idbModeReadWrite);
        final store = t.objectStore('store');

        return store.getObject(1);
      }

      test('key_path_cursor_update_with_explicit_id', () async {
        final db = await getDb();

        try {
          final obj = <String, Object?>{'key': 1, 'someval': 'lorem'};
          final obj2 = <String, Object?>{'key': 1, 'someval': 'ipsem'};

          await insert(db, obj);
          await update(db, obj2);
          final ret = await get(db, 1);

          expect(ret, equals(obj2));
        } finally {
          db.close();
        }
      });

      test('key_path_cursor_update_with_auto_incremented_id', () async {
        final db = await getDb();

        try {
          final obj = <String, Object?>{'someval': 'lorem'};
          final key = await insert(db, obj);
          final obj2 = <String, Object?>{'key': key, 'someval': 'ipsem'};

          await update(db, obj2);
          final ret = await get(db, 1);

          expect(ret, equals(obj2));
        } finally {
          db.close();
        }
      });
    });
  });
}
