import 'package:idb_shim/sdb.dart';

import 'idb_test_common.dart';

void main() {
  idbSimpleSdbTest(idbMemoryContext);
}

var testStore = SdbStoreRef<int, SdbModel>('test');

var testStore2 = SdbStoreRef<String, SdbModel>('test2');

class SdbTestContext {
  final SdbFactory factory;

  SdbTestContext(this.factory);
}

void idbSimpleSdbTest(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);
  simpleSdbTest(SdbTestContext(factory));
}

/// Simple SDB test
void simpleSdbTest(SdbTestContext ctx) {
  var factory = ctx.factory;

  group('sdb', () {
    test('open/close', () async {
      var db = await factory.openDatabase('test.db');
      await db.close();
    });
    group('int key', () {
      test('put/get/delete int', () async {
        await factory.deleteDatabase('test_put_get.db');
        var db = await factory.openDatabase(
          'test_put_get.db',
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(testStore);
            }
          },
        );
        var key = await testStore.add(db, {'test': 1});
        expect(key, 1);
        var key2 = await testStore.add(db, {'test': 2});
        expect(key2, 2);
        // ignore: omit_local_variable_types
        SdbRecordRef<int, SdbModel> recordRef = testStore.record(key);
        // ignore: omit_local_variable_types
        SdbRecordSnapshot<int, SdbModel> record = (await recordRef.get(db))!;
        expect(record.value, {'test': 1});
        expect(record.key, key);
        expect(await testStore.record(key).getValue(db), {'test': 1});
        record = (await testStore.record(key2).get(db))!;
        expect(record.value, {'test': 2});
        expect(await testStore.record(3).get(db), isNull);
        await testStore.record(key).delete(db);
        expect(await testStore.record(key).get(db), isNull);
        await testStore.record(key).put(db, {'test': 3});
        record = (await testStore.record(key).get(db))!;
        expect(record.value, {'test': 3});
        expect(record.key, key);
        await db.close();
      });
      test('txn put/get/delete int', () async {
        await factory.deleteDatabase('test_put_get.db');
        var db = await factory.openDatabase(
          'test_put_get.db',
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(testStore);
            }
          },
        );
        await db.inStoreTransaction(testStore, SdbTransactionMode.readWrite, (
          txn,
        ) async {
          var key = await testStore.add(txn, {'test': 1});
          expect(key, 1);
          var key2 = await testStore.add(txn, {'test': 2});
          expect(key2, 2);

          var record = (await testStore.record(key).get(txn))!;
          expect(record.value, {'test': 1});
          expect(record.key, key);
          record = (await testStore.record(key2).get(txn))!;
          expect(record.value, {'test': 2});
          expect(await testStore.record(3).get(txn), isNull);
          await testStore.record(key).delete(txn);
          expect(await testStore.record(key).get(txn), isNull);

          await testStore.record(key).put(txn, {'test': 3});
          record = (await testStore.record(key).get(txn))!;
          expect(record.value, {'test': 3});
          expect(record.key, key);
        });
        /*
     */
        await db.close();
      });
      test('basic filter', () async {
        await factory.deleteDatabase('test_basic_filter.db');
        var db = await factory.openDatabase(
          'test_basic_filter.db',
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(testStore);
            }
          },
        );
        await db.inStoreTransaction(testStore, SdbTransactionMode.readWrite, (
          txn,
        ) async {
          await txn.add({'test': 10});
          await txn.add({'test': 20});
          await txn.add({'test': 30});
        });
        var filter = SdbFilter.equals('test', 20);
        var records = await testStore.findRecords(db, filter: filter);
        expect(records.length, 1);
        expect(records.keys, [2]);

        records = await testStore.findRecords(
          db,
          filter: SdbFilter.notEquals('test', 20),
        );
        expect(records.keys, [1, 3]);

        /// Custom filter
        var customEvaluated = false;
        records = await testStore.findRecords(
          db,
          filter: SdbFilter.and([
            filter,
            SdbFilter.custom((snapshot) {
              //devPrint('snapshot: $snapshot');
              expect(customEvaluated, isFalse);
              customEvaluated = true;
              expect(snapshot.key, 2);
              expect(snapshot.primaryKey, 2);
              expect(
                snapshot.indexKey,
                2,
              ); // Value could change but is what it is now...
              return true;
            }),
          ]),
        );
        expect(customEvaluated, isTrue);
        expect(records.keys, [2]);
        await db.close();

        await db.close();
      });
      test('boundaries int', () async {
        await factory.deleteDatabase('test_boundaries.db');
        var db = await factory.openDatabase(
          'test_boundaries.db',
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(testStore);
            }
          },
        );
        await db.inStoreTransaction(testStore, SdbTransactionMode.readWrite, (
          txn,
        ) async {
          await txn.add({'test': 1});
          await txn.add({'test': 2});
          await txn.add({'test': 3});
        });
        var boundaries = SdbBoundaries(
          SdbLowerBoundary(1),
          SdbUpperBoundary(3),
        );
        var records = await testStore.findRecords(db, boundaries: boundaries);
        expect(records.length, 2);
        records = await testStore.findRecords(
          db,
          boundaries: boundaries,
          limit: 1,
        );
        expect(records.keys, [1]);
        records = await testStore.findRecords(
          db,
          boundaries: boundaries,
          limit: 1,
          descending: true,
        );
        expect(records.keys, [2]);
        var keys = await testStore.findRecordKeys(db, boundaries: boundaries);
        expect(keys.keys, [1, 2]);
        keys = await testStore.findRecordKeys(
          db,
          boundaries: boundaries,
          limit: 1,
        );
        expect(keys.keys, [1]);
        keys = await testStore.findRecordKeys(
          db,
          boundaries: boundaries,
          limit: 1,
          descending: true,
        );
        expect(keys.keys, [2]);
        var count = await testStore.count(db, boundaries: boundaries);
        expect(count, 2);

        await testStore.delete(db, boundaries: boundaries);
        expect(await testStore.count(db), 1);
        await db.close();
      });

      test('txn boundaries int', () async {
        await factory.deleteDatabase('test_boundaries.db');
        var db = await factory.openDatabase(
          'test_boundaries.db',
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(testStore);
            }
          },
        );
        await db.inStoreTransaction(testStore, SdbTransactionMode.readWrite, (
          txn,
        ) async {
          await txn.add({'test': 1});
          await txn.add({'test': 2});
          await txn.add({'test': 3});

          var boundaries = SdbBoundaries(
            SdbLowerBoundary(1),
            SdbUpperBoundary(3),
          );
          var records = await testStore.findRecords(
            txn,
            boundaries: boundaries,
          );
          expect(records.length, 2);
          records = await testStore.findRecords(
            txn,
            boundaries: boundaries,
            limit: 1,
          );
          expect(records.keys, [1]);
          records = await testStore.findRecords(
            txn,
            boundaries: boundaries,
            limit: 1,
            descending: true,
          );
          expect(records.keys, [2]);
          records = await testStore.findRecords(
            txn,
            boundaries: boundaries,
            limit: 1,
            descending: true,
            offset: 1,
          );
          expect(records.keys, [1]);

          var keys = await testStore.findRecordKeys(
            txn,
            boundaries: boundaries,
          );
          expect(keys.keys, [1, 2]);
          keys = await testStore.findRecordKeys(
            txn,
            boundaries: boundaries,
            limit: 1,
            offset: 1,
            descending: true,
          );
          expect(keys.keys, [1]);
          var count = await testStore.count(txn, boundaries: boundaries);
          expect(count, 2);

          await testStore.delete(
            txn,
            boundaries: boundaries,
            descending: true,
            limit: 1,
          );
          keys = await testStore.findRecordKeys(txn);
          expect(keys.keys, [1, 3]);
          await testStore.delete(txn, boundaries: boundaries);
          keys = await testStore.findRecordKeys(txn);
          expect(keys.keys, [3]);
          await testStore.delete(txn);
          keys = await testStore.findRecordKeys(txn);
          expect(keys, isEmpty);
        });

        await db.close();
      });
    });

    group('string key', () {
      test('put/get/delete string', () async {
        await factory.deleteDatabase('test_put_get.db');
        var db = await factory.openDatabase(
          'test_put_get.db',
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(testStore2);
            }
          },
        );
        var key = await testStore2.add(db, {'test': 1});
        expect(key.isNotEmpty, isTrue);
        var key2 = await testStore2.add(db, {'test': 2});
        var record = (await testStore2.record(key).get(db))!;
        expect(record.value, {'test': 1});
        expect(record.key, key);
        record = (await testStore2.record(key2).get(db))!;
        expect(record.value, {'test': 2});
        expect(await testStore2.record('dummy').get(db), isNull);
        await testStore2.record(key).delete(db);
        expect(await testStore2.record(key).get(db), isNull);

        await db.close();
      });
      test('keyPath int auto', () async {
        var dbName = 'test_key_path_auto_put_get.db';
        await factory.deleteDatabase(dbName);
        var db = await factory.openDatabase(
          dbName,
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(
                testStore,
                keyPath: 'id',
                autoIncrement: true,
              );
            }
          },
        );
        var key = await testStore.add(db, {'test': 1});
        var readValue = await testStore.record(key).getValue(db);
        expect(readValue, {'test': 1, 'id': key});
        await db.close();
      });
      test('keyPath string', () async {
        var dbName = 'test_key_path_put_get.db';
        await factory.deleteDatabase(dbName);
        var db = await factory.openDatabase(
          dbName,
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(testStore2, keyPath: 'id');
            }
          },
        );
        var key = await testStore2.add(db, {'test': 1, 'id': 'my_id'});
        expect(key, 'my_id');
        var readValue = await testStore2.record(key).getValue(db);
        expect(readValue, {'test': 1, 'id': key});
        await db.close();
      });
    });

    test('multi store', () async {
      var dbName = 'test_multi_store.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(
        dbName,
        version: 1,
        onVersionChange: (event) {
          var oldVersion = event.oldVersion;
          if (oldVersion < 1) {
            event.db.createStore(testStore);
            event.db.createStore(testStore2);
          }
        },
      );
      await db.inStoresTransaction(
        [testStore, testStore2],
        SdbTransactionMode.readWrite,
        (txn) async {
          var key = await txn.txnStore(testStore).add({'test': 1});
          var key2 = await txn.txnStore(testStore2).add({'test': 2});
          expect(key, 1);
          expect(key2.isNotEmpty, isTrue);
        },
      );

      await db.close();
    });
  });
}
