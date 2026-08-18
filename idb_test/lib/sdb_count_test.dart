import 'package:idb_shim/sdb.dart';

import 'idb_test_common.dart';

void main() {
  idbSdbCountTests(idbMemoryContext);
}

var countTestStore = SdbStoreRef<int, SdbModel>('count_test');
var countTestIndex = countTestStore.index<String>('name');

/// Count tests, the count must always agree with the number of records a
/// findRecords with the same options returns, offset and limit included.
void idbSdbCountTests(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);

  group('sdb_count', () {
    late SdbDatabase db;
    var dbName = 'sdb_count.db';

    /// name_0 .. name_9
    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              countTestStore.schema(
                indexes: [countTestIndex.schema(keyPath: 'name')],
              ),
            ],
          ),
        ),
      );
      await db.inStoreTransaction(
        countTestStore,
        SdbTransactionMode.readWrite,
        (txn) async {
          for (var i = 0; i < 10; i++) {
            await countTestStore.record(i).put(txn, {'name': 'name_$i'});
          }
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    /// Count and findRecords must agree, returns the count.
    Future<int> storeCount(SdbFindOptions<int>? options) async {
      var count = await countTestStore.count(db, options: options);
      var records = await countTestStore.findRecords(db, options: options);
      expect(count, records.length, reason: 'options: $options');
      return count;
    }

    Future<int> indexCount(SdbFindOptions<String>? options) async {
      var count = await countTestIndex.count(db, options: options);
      var records = await countTestIndex.findRecords(db, options: options);
      expect(count, records.length, reason: 'options: $options');
      return count;
    }

    test('store count offset/limit', () async {
      expect(await storeCount(null), 10);
      expect(await storeCount(SdbFindOptions()), 10);
      expect(await storeCount(SdbFindOptions(offset: 3)), 7);
      expect(await storeCount(SdbFindOptions(offset: 10)), 0);
      expect(await storeCount(SdbFindOptions(offset: 20)), 0);
      // The limit caps the count.
      expect(await storeCount(SdbFindOptions(limit: 4)), 4);
      expect(await storeCount(SdbFindOptions(limit: 10)), 10);
      expect(await storeCount(SdbFindOptions(limit: 20)), 10);
      expect(await storeCount(SdbFindOptions(offset: 3, limit: 4)), 4);
      expect(await storeCount(SdbFindOptions(offset: 8, limit: 4)), 2);
      expect(await storeCount(SdbFindOptions(offset: 10, limit: 4)), 0);
    });

    test('store count boundaries and offset/limit', () async {
      // name_2 .. name_9
      var boundaries = SdbBoundaries<int>(
        countTestStore.lowerBoundary(2),
        null,
      );
      expect(await storeCount(SdbFindOptions(boundaries: boundaries)), 8);
      expect(
        await storeCount(SdbFindOptions(boundaries: boundaries, limit: 3)),
        3,
      );
      expect(
        await storeCount(SdbFindOptions(boundaries: boundaries, limit: 20)),
        8,
      );
      expect(
        await storeCount(
          SdbFindOptions(boundaries: boundaries, offset: 6, limit: 5),
        ),
        2,
      );
    });

    test('store count filter and offset/limit', () async {
      // The filtered count goes through a different (slow) path, it must
      // apply the limit the same way.
      var filter = SdbFilter.custom(
        (snapshot) => (snapshot['name'] as String).compareTo('name_4') >= 0,
      );
      expect(await storeCount(SdbFindOptions(filter: filter)), 6);
      expect(await storeCount(SdbFindOptions(filter: filter, limit: 2)), 2);
      expect(await storeCount(SdbFindOptions(filter: filter, limit: 20)), 6);
      expect(
        await storeCount(SdbFindOptions(filter: filter, offset: 4, limit: 5)),
        2,
      );
    });

    test('index count offset/limit', () async {
      expect(await indexCount(null), 10);
      expect(await indexCount(SdbFindOptions()), 10);
      expect(await indexCount(SdbFindOptions(offset: 3)), 7);
      expect(await indexCount(SdbFindOptions(offset: 10)), 0);
      // The limit caps the count.
      expect(await indexCount(SdbFindOptions(limit: 4)), 4);
      expect(await indexCount(SdbFindOptions(limit: 10)), 10);
      expect(await indexCount(SdbFindOptions(limit: 20)), 10);
      expect(await indexCount(SdbFindOptions(offset: 3, limit: 4)), 4);
      expect(await indexCount(SdbFindOptions(offset: 8, limit: 4)), 2);
      expect(await indexCount(SdbFindOptions(offset: 10, limit: 4)), 0);
    });

    test('index count boundaries and offset/limit', () async {
      // name_2 .. name_9
      var boundaries = SdbBoundaries<String>(
        countTestIndex.lowerBoundary('name_2'),
        null,
      );
      expect(await indexCount(SdbFindOptions(boundaries: boundaries)), 8);
      expect(
        await indexCount(SdbFindOptions(boundaries: boundaries, limit: 3)),
        3,
      );
      expect(
        await indexCount(SdbFindOptions(boundaries: boundaries, limit: 20)),
        8,
      );
      expect(
        await indexCount(
          SdbFindOptions(boundaries: boundaries, offset: 6, limit: 5),
        ),
        2,
      );
    });

    test('index count filter and offset/limit', () async {
      var filter = SdbFilter.custom(
        (snapshot) => (snapshot['name'] as String).compareTo('name_4') >= 0,
      );
      expect(await indexCount(SdbFindOptions(filter: filter)), 6);
      expect(await indexCount(SdbFindOptions(filter: filter, limit: 2)), 2);
      expect(await indexCount(SdbFindOptions(filter: filter, limit: 20)), 6);
    });
  });
}
