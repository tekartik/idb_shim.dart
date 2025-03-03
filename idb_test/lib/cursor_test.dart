library;

import 'package:idb_shim/utils/idb_cursor_utils.dart';
import 'package:idb_shim/utils/idb_utils.dart';

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

  void dbCreateTransaction() {
    transaction = db!.transaction(testStoreName, idbModeReadWrite);
    objectStore = transaction!.objectStore(testStoreName);
  }

  // prepare for test
  Future<String> setupDeleteDb() async {
    dbName = ctx.dbName;
    await idbFactory.deleteDatabase(dbName);
    return dbName;
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
    // ignore: unused_local_variable
    late Object key1, key2, key3;
    Future<Object> add(String name) {
      var obj = {testNameField: name};
      return objectStore.put(obj);
    }

    Future fill3SampleRows() async {
      key1 = await add('test2');
      key2 = await add('test1');
      key3 = await add('test3');
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

    Future<List<TestIdNameRow>> testCursorToList(
      Stream<CursorWithValue> stream,
    ) {
      final list = <TestIdNameRow>[];
      return stream
          .listen((CursorWithValue cwv) {
            list.add(TestIdNameRow(cwv));
          })
          .asFuture(list);
    }

    Future<List<TestIdNameRow>> manualCursorToList(
      Stream<CursorWithValue> stream,
    ) {
      final list = <TestIdNameRow>[];
      return stream
          .listen((CursorWithValue cwv) {
            list.add(TestIdNameRow(cwv));
            cwv.next();
          })
          .asFuture(list);
    }

    group('key_path_with_dot', () {
      const keyPath = 'my.key';

      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, keyPath: keyPath);
        }

        db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: onUpgradeNeeded,
        );
      }

      tearDown(dbTearDown);

      test('one item cursor', () async {
        await dbSetUp();
        dbCreateTransaction();
        var value = {
          'my': {'key': 'test_value'},
        };
        await objectStore.add(value);
        final stream = objectStore.openCursor(
          autoAdvance: true,
          key: 'test_value',
        );
        var count = 0;
        final completer = Completer<void>.sync();
        stream
            .listen((CursorWithValue cwv) {
              expect(cwv.value, value);
              count++;
            })
            .onDone(() {
              completer.complete();
            });
        await completer.future;
        expect(count, 1);
        // Key cursor
        {
          final stream = objectStore.openKeyCursor(
            autoAdvance: true,
            key: 'test_value',
          );
          var count = 0;
          await stream.listen((Cursor cursor) {
            expect(cursor, isNot(const TypeMatcher<CursorWithValue>()));
            expect(cursor.key, 'test_value');
            expect(cursor.primaryKey, 'test_value');
            count++;
          }).asFuture<void>();

          expect(count, 1);
        }
        var valueRead = false;

        // Cancel subscription
        {
          final stream = objectStore.openCursor(
            autoAdvance: true,
            key: 'test_value',
          );

          var subscription = stream.listen((cwv) {
            valueRead = true;
          });
          unawaited(subscription.cancel());
        }

        // Cancel subscription no auto advance
        {
          final stream = objectStore.openCursor(
            autoAdvance: false,
            key: 'test_value',
          );

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

        final db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (VersionChangeEvent change) {
            change.database.createObjectStore('store1', keyPath: 'key');
          },
        );
        try {
          final obj = <String, Object?>{'key': 1, 'someval': 'lorem'};
          final obj2 = <String, Object?>{'key': 1, 'someval': 'ipsem'};
          final t1 = db.transaction('store1', idbModeReadWrite);
          final store1 = t1.objectStore('store1');
          unawaited(store1.put(obj));
          await t1.completed;

          final t2 = db.transaction('store1', idbModeReadWrite);
          final store2 = t2.objectStore('store1');
          unawaited(
            store2.openCursor().forEach((cv) {
              expect(cv.key, 1);
              expect(cv.primaryKey, 1);
              expect(cv.value, obj);

              cv.update(obj2);
            }),
          );
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

        final db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (VersionChangeEvent change) {
            change.database.createObjectStore(
              'store1',
              keyPath: 'key',
              autoIncrement: true,
            );
          },
        );
        try {
          final obj = <String, Object?>{'key': 1, 'someval': 'lorem'};
          final obj2 = <String, Object?>{'key': 1, 'someval': 'ipsem'};
          final t1 = db.transaction('store1', idbModeReadWrite);
          final store1 = t1.objectStore('store1');
          unawaited(store1.put(obj));
          await t1.completed;

          final t2 = db.transaction('store1', idbModeReadWrite);
          final store2 = t2.objectStore('store1');
          unawaited(
            store2.openCursor().forEach((cv) {
              expect(cv.key, 1);
              expect(cv.primaryKey, 1);
              expect(cv.value, obj);

              cv.update(obj2);
            }),
          );
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

      test('cursor key delete failed', () async {
        var dbName = 'key_path_auto_cursor_delete.db';
        await idbFactory.deleteDatabase(dbName);

        final db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (VersionChangeEvent change) {
            change.database.createObjectStore(
              'store1',
              keyPath: 'key',
              autoIncrement: true,
            );
          },
        );
        final obj = <String, Object?>{'key': 1, 'someval': 'lorem'};

        final t1 = db.transaction('store1', idbModeReadWrite);
        final store1 = t1.objectStore('store1');
        unawaited(store1.put(obj));

        Object? cursorException;

        try {
          await store1.openKeyCursor(autoAdvance: false).listen((
            Cursor cursor,
          ) async {
            // This fails on Chrome, mimic on idb
            try {
              await cursor.delete().then((_) {
                cursor.next();
              });
            } catch (e) {
              cursorException = e;
              print('cursorException: $cursorException');
              cursor.next();
            }
          }).asFuture<void>();
          await t1.completed;
        } catch (e) {
          print(e);
          expect(e, isNot(isA<TestFailure>()));
        }
      }); // Remove if it hangs on Chrome

      test('key_path_auto_cursor_update', () async {
        var dbName = 'key_path_auto_cursor_update.db';
        await idbFactory.deleteDatabase(dbName);

        final db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (VersionChangeEvent change) {
            change.database.createObjectStore(
              'store1',
              keyPath: 'key',
              autoIncrement: true,
            );
          },
        );
        try {
          final obj = <String, Object?>{'key': 1, 'someval': 'lorem'};
          final obj2 = <String, Object?>{'key': 1, 'someval': 'ipsem'};
          final t1 = db.transaction('store1', idbModeReadWrite);
          final store1 = t1.objectStore('store1');
          unawaited(store1.put(obj));
          await t1.completed;

          final t2 = db.transaction('store1', idbModeReadWrite);
          final store2 = t2.objectStore('store1');
          unawaited(
            store2.openCursor().forEach((cv) {
              expect(cv.key, 1);
              expect(cv.primaryKey, 1);
              expect(cv.value, obj);

              cv.update(obj2);
            }),
          );
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
    Future dbSetUp() async {
      await setupDeleteDb();
      void onUpgradeNeeded(VersionChangeEvent e) {
        final db = e.database;
        //ObjectStore objectStore =
        db.createObjectStore(testStoreName, autoIncrement: true);
      }

      db = await idbFactory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: onUpgradeNeeded,
      );
    }

    group('non_auto', () {
      tearDown(dbTearDown);

      test('cursorToList', () async {
        await dbSetUp();
        dbCreateTransaction();
        await fill3SampleRows();

        expect((await objectStore.openCursor().toRowList()).values, [
          {'name': 'test2'},
          {'name': 'test1'},
          {'name': 'test3'},
        ]);
        expect((await objectStore.openCursor().toRowList(offset: 1)).values, [
          {'name': 'test1'},
          {'name': 'test3'},
        ]);
        expect((await objectStore.openCursor().toRowList(limit: 1)).values, [
          {'name': 'test2'},
        ]);

        expect(
          (await objectStore.openCursor().toRowList(
            limit: 1,
            matcher: (cwv) {
              var map = cwv.value as Map;
              return map['name'] != 'test1';
            },
          )).values,
          [
            {'name': 'test2'},
          ],
        );
        expect(
          (await objectStore.openCursor().toRowList(
            offset: 1,
            limit: 1,
          )).values,
          [
            {'name': 'test1'},
          ],
        );
        expect(
          await objectStore.openCursor().toValueList(offset: 1, limit: 1),
          [
            {'name': 'test1'},
          ],
        );

        expect(
          await objectStore.openCursor().toPrimaryKeyList(offset: 1, limit: 1),
          [key2],
        );
        expect(
          (await objectStore.openCursor().toKeyRowList(
            offset: 1,
            limit: 1,
          )).map((e) => e.key),
          [key2],
        );
        expect(await objectStore.openCursor().toKeyList(offset: 1, limit: 1), [
          key2,
        ]);
      });
    });
    group('auto', () {
      tearDown(dbTearDown);

      test('empty cursor', () async {
        await dbSetUp();
        dbCreateTransaction();
        final stream = objectStore.openCursor(autoAdvance: true);
        var count = 0;
        return stream
            .listen((CursorWithValue cwv) {
              count++;
            })
            .asFuture<void>()
            .then((_) {
              expect(count, 0);
            });
      });

      test('one_item_cursor', () async {
        await dbSetUp();
        dbCreateTransaction();
        return add('test1').then((_) {
          final stream = objectStore.openCursor(autoAdvance: true);
          var count = 0;
          final completer = Completer<void>();
          stream
              .listen((CursorWithValue cwv) {
                expect((cwv.value as Map)[testNameField], 'test1');
                count++;
              })
              .onDone(() {
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
        objectStore.openCursor(autoAdvance: false).listen((
          CursorWithValue cwv,
        ) {
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
              .asFuture<void>()
              .timeout(
                const Duration(milliseconds: 500),
                onTimeout: () {
                  // don't wait on the transaction
                  transaction = null;
                  return null;
                },
              );
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
              .asFuture<void>()
              .timeout(
                const Duration(milliseconds: 500),
                onTimeout: () {
                  // don't wait on the transaction
                  transaction = null;
                },
              );
          expect(transaction, isNull);
        });
      });
      test('3 item cursor no auto advance', () async {
        await dbSetUp();
        dbCreateTransaction();
        return fill3SampleRows().then((_) {
          return manualCursorToList(
            objectStore.openCursor(autoAdvance: false),
          ).then((list) {
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
          return testCursorToList(
            objectStore.openCursor(autoAdvance: true),
          ).then((list) {
            expect(list[0].name, equals('test2'));
            expect(list[0].id, equals(1));
            expect(list[1].name, equals('test1'));
            expect(list[2].name, equals('test3'));
            expect(list[2].id, equals(3));
            expect(list.length, 3);

            return testCursorToList(
              objectStore.openCursor(
                range: KeyRange.bound(2, 3),
                autoAdvance: true,
              ),
            ).then((list) {
              expect(list.length, 2);
              expect(list[0].name, equals('test1'));
              expect(list[0].id, equals(2));
              expect(list[1].name, equals('test3'));
              expect(list[1].id, equals(3));

              return testCursorToList(
                objectStore.openCursor(
                  range: KeyRange.bound(1, 3, true, true),
                  autoAdvance: true,
                ),
              ).then((list) {
                expect(list.length, 1);
                expect(list[0].name, equals('test1'));
                expect(list[0].id, equals(2));

                return testCursorToList(
                  objectStore.openCursor(
                    range: KeyRange.lowerBound(2),
                    autoAdvance: true,
                  ),
                ).then((list) {
                  expect(list.length, 2);
                  expect(list[0].name, equals('test1'));
                  expect(list[0].id, equals(2));
                  expect(list[1].name, equals('test3'));
                  expect(list[1].id, equals(3));

                  return testCursorToList(
                    objectStore.openCursor(
                      range: KeyRange.upperBound(2, true),
                      autoAdvance: true,
                    ),
                  ).then((list) {
                    expect(list.length, 1);
                    expect(list[0].name, equals('test2'));
                    expect(list[0].id, equals(1));

                    return testCursorToList(
                      objectStore.openCursor(key: 2, autoAdvance: true),
                    ).then((list) {
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
      test('invalid range cursor', () async {
        await dbSetUp();
        dbCreateTransaction();
        try {
          objectStore.openCursor(
            autoAdvance: true,
            range: KeyRange.bound(1, 1, false, true),
          );
          fail('should fail');
        } catch (e) {
          // Chrome: DataError: Failed to execute 'bound' on 'IDBKeyRange': The lower key and upper key are equal and one of the bounds is open.
          print(e);
          expect(e, isNot(isA<TestFailure>()));
        }
      });

      test('autoCursorToList', () async {
        await dbSetUp();
        dbCreateTransaction();
        await fill3SampleRows();

        var list = (await cursorToList(
          objectStore.openCursor(autoAdvance: true),
        )).map((e) => e.value);
        expect(list, [
          {'name': 'test2'},
          {'name': 'test1'},
          {'name': 'test3'},
        ]);
        print('#3-');
        list = (await cursorToList(
          objectStore.openCursor(autoAdvance: true),
        )).map((e) => e.value);
        expect(list, [
          {'name': 'test2'},
          {'name': 'test1'},
          {'name': 'test3'},
        ]);
        print('#4-');
        /*
        list = (await cursorToList(objectStore.openCursor(), offset: 1)).map((e) => e.value);
        expect(list, [
          {'name': 'test1'},
          {'name': 'test3'}
        ]);*/
      });
    });

    group('issue#42', () {
      Future<Database> getDb() async {
        var dbName = await setupDeleteDb();
        await idbFactory.deleteDatabase(dbName);

        return idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (VersionChangeEvent change) {
            change.database.createObjectStore(
              'store',
              keyPath: 'key',
              autoIncrement: true,
            );
          },
        );
      }

      Future<Object> insert(Database db, Map<String, Object?> obj) async {
        final t = db.transaction('store', idbModeReadWrite);
        final store = t.objectStore('store');

        final ret = await store.put(obj);
        await t.completed;
        return ret;
      }

      Future<Object?> get(Database db, Object key) {
        final t = db.transaction('store', idbModeReadWrite);
        final store = t.objectStore('store');

        return store.getObject(key);
      }

      Future<void> update(Database db, Map<String, Object?> obj) async {
        final t = db.transaction('store', idbModeReadWrite);
        final store = t.objectStore('store');

        unawaited(
          store.openCursor(autoAdvance: true).forEach((cv) {
            // change: update the correct row
            if (cv.key == obj['key']) {
              cv.update(obj);
            }
          }),
        );
        await t.completed;
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

      test('key_path_cursor_update_with_multiple_rows', () async {
        final db = await getDb();

        try {
          final obj = <String, Object?>{'someval': 'lorem'};
          final key = await insert(db, obj);
          final obj2 = <String, Object?>{'someval': 'lorem'};
          final key2 = await insert(db, obj2);

          await update(db, {'key': key, 'someval': 'ipsem'});
          await update(db, {'key': key2, 'someval': 'ipsem'});
          final ret = await get(db, key);
          final ret2 = await get(db, key2);
          print(ret);
          print(ret2);
          expect(ret, equals({'key': key, 'someval': 'ipsem'}));
          expect(ret2, equals({'key': key2, 'someval': 'ipsem'}));
        } finally {
          db.close();
        }
      });
    });

    group('composite_key', () {
      const keyPath = ['my', 'key'];

      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, keyPath: keyPath);
        }

        db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: onUpgradeNeeded,
        );
      }

      test('put/openCursor', () async {
        await dbSetUp();
        dbCreateTransaction();
        var map = {'my': 1, 'key': 'value'};
        var key = await objectStore.put(map);
        expect(key, [1, 'value']);
        var keyRows = await keyCursorToList(
          objectStore.openKeyCursor(autoAdvance: true),
        );
        var keyRow = keyRows.first;

        expect(keyRow.key, key);
        expect(keyRow.primaryKey, key);

        var rows = await cursorToList(
          objectStore.openCursor(autoAdvance: true),
        );
        var row = rows.first;

        expect(row.key, key);
        expect(row.primaryKey, key);
        expect(row.value, map);

        var map2 = {'my': 1, 'key': 'value2'};
        var key2 = await objectStore.put(map2);
        keyRows = await keyCursorToList(
          objectStore.openKeyCursor(autoAdvance: true),
        );
        expect(keyRows, hasLength(2));
        keyRow = keyRows.first;
        expect(keyRow.key, key);
        keyRow = keyRows[1];
        expect(keyRow.key, key2);
        keyRows = await keyCursorToList(
          objectStore.openKeyCursor(
            autoAdvance: true,
            range: KeyRange.lowerBound([1, 'value2']),
          ),
        );
        expect(keyRows, hasLength(1));

        // Not supported
        // ignore: dead_code
        if (false) {
          keyRows = await keyCursorToList(
            objectStore.openKeyCursor(
              autoAdvance: true,
              range: KeyRange.lowerBound([1, null]),
            ),
          );
          expect(keyRows, hasLength(2));
          var map3 = {'my': 2, 'key': 'value1'};
          // ignore: unused_local_variable
          var key3 = await objectStore.put(map3);
          keyRows = await keyCursorToList(
            objectStore.openKeyCursor(
              autoAdvance: true,
              range: KeyRange.lowerBound([2, null]),
            ),
          );
          expect(keyRows, hasLength(1));
        }

        var map3 = {'my': 2, 'key': 'value1'};
        // ignore: unused_local_variable
        var key3 = await objectStore.put(map3);

        var keys = await cursorToPrimaryKeyList(
          objectStore.openKeyCursor(
            autoAdvance: true,
            range: KeyRange.lowerBound([1, '']),
          ),
        );
        expect(keys, [key, key2, key3]);
        keys = await cursorToKeyList(
          objectStore.openKeyCursor(
            autoAdvance: true,
            range: KeyRange.bound([1, ''], [2, ''], false, true),
          ),
        );
        expect(keys, [key, key2]);
      });

      tearDown(dbTearDown);
    });
  });
}
