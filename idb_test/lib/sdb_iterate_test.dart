import 'package:idb_shim/sdb.dart';

import 'idb_test_common.dart';
import 'sdb_test.dart' show SdbTestContext;

void main() {
  idbSdbIterateTests(idbMemoryContext);
}

var iterateTestStore = SdbStoreRef<int, SdbModel>('iterate_test');
var iterateTestIndex = iterateTestStore.index<String>('name');

/// Iterate tests on an idb factory.
void idbSdbIterateTests(TestContext ctx) {
  sdbIterateTests(SdbTestContext(sdbFactoryFromIdb(ctx.factory)));
}

/// Iterate (errors, update), limit 0 and codec tests.
void sdbIterateTests(SdbTestContext ctx) {
  var factory = ctx.factory;

  group('sdb_iterate', () {
    late SdbDatabase db;
    var dbName = 'sdb_iterate.db';

    /// name_0 .. name_4
    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              iterateTestStore.schema(
                indexes: [iterateTestIndex.schema(keyPath: 'name')],
              ),
            ],
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await iterateTestStore.record(i).put(db, {'name': 'name_$i'});
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('onRow error', () async {
      try {
        await iterateTestStore.iterate(
          db,
          onRow: (row) {
            throw StateError('store');
          },
        );
        fail('should fail');
      } on StateError catch (e) {
        expect(e.message, 'store');
      }
      try {
        await iterateTestStore.iterate(
          db,
          onRow: (row) async {
            throw StateError('store async');
          },
        );
        fail('should fail');
      } on StateError catch (e) {
        expect(e.message, 'store async');
      }
      try {
        await iterateTestIndex.iterate(
          db,
          onRow: (row) {
            throw StateError('index');
          },
        );
        fail('should fail');
      } on StateError catch (e) {
        expect(e.message, 'index');
      }
      // Still usable
      expect(await iterateTestStore.count(db), 5);
    });

    test('row update', () async {
      var timestamp = SdbTimestamp.fromMillisecondsSinceEpoch(1000);
      var recordSnapshots = <Object?>[];
      var subscription = iterateTestStore
          .record(0)
          .onSnapshot(db)
          .listen((snapshot) => recordSnapshots.add(snapshot?.value['name']));
      try {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await iterateTestStore.iterate(
          db,
          mode: SdbTransactionMode.readWrite,
          options: SdbFindOptions(limit: 1),
          onRow: (row) async {
            // Encoded like a put
            await row.update({'name': 'store', 't': timestamp});
            return true;
          },
        );
        var value = (await iterateTestStore.record(0).get(db))!.value;
        expect(value, {'name': 'store', 't': timestamp});
        await iterateTestIndex.iterate(
          db,
          mode: SdbTransactionMode.readWrite,
          options: SdbFindOptions<String>(
            boundaries: SdbBoundaries(
              iterateTestIndex.lowerBoundary('store'),
              null,
            ),
          ),
          onRow: (row) async {
            await row.update({'name': 'index', 't': timestamp});
            return true;
          },
        );
        value = (await iterateTestStore.record(0).get(db))!.value;
        expect(value, {'name': 'index', 't': timestamp});
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // The listener is notified
        expect(recordSnapshots, ['name_0', 'store', 'index']);
      } finally {
        await subscription.cancel();
      }
    });

    test('limit 0', () async {
      var options = SdbFindOptions<int>(limit: 0);
      var indexOptions = SdbFindOptions<String>(limit: 0);
      expect(await iterateTestStore.findRecords(db, options: options), isEmpty);
      expect(
        await iterateTestStore.findRecords(
          db,
          options: options.copyWith(
            filter: SdbFilter.notEquals('name', 'none'),
          ),
        ),
        isEmpty,
      );
      expect(
        await iterateTestStore.streamRecords(db, options: options).toList(),
        isEmpty,
      );
      expect(
        await iterateTestStore.findRecordKeys(db, options: options),
        isEmpty,
      );
      expect(await iterateTestStore.count(db, options: options), 0);
      var rowCount = 0;
      await iterateTestStore.iterate(
        db,
        options: options,
        onRow: (row) {
          rowCount++;
          return true;
        },
      );
      await iterateTestIndex.iterate(
        db,
        options: indexOptions,
        onRow: (row) {
          rowCount++;
          return true;
        },
      );
      expect(rowCount, 0);
      expect(
        await iterateTestIndex.findRecords(db, options: indexOptions),
        isEmpty,
      );
      expect(
        await iterateTestIndex
            .streamRecords(db, options: indexOptions)
            .toList(),
        isEmpty,
      );
      expect(
        await iterateTestIndex.findRecordKeys(db, options: indexOptions),
        isEmpty,
      );
      expect(await iterateTestIndex.count(db, options: indexOptions), 0);
      await iterateTestIndex.delete(db, options: indexOptions);
      await iterateTestStore.delete(db, options: options);
      expect(await iterateTestStore.count(db), 5);
    });

    test('nested untyped map', () async {
      await iterateTestStore.record(10).put(db, {
        'name': 'nested',
        'map': <dynamic, dynamic>{'k': 'v', 'n': 1},
        'list': [
          <dynamic, dynamic>{'k': 'v'},
        ],
      });
      expect((await iterateTestStore.record(10).get(db))!.value, {
        'name': 'nested',
        'map': {'k': 'v', 'n': 1},
        'list': [
          {'k': 'v'},
        ],
      });
    });
  });
}
