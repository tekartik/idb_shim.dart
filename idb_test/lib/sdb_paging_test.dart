import 'package:idb_shim/sdb.dart';

import 'idb_test_common.dart';

void main() {
  idbSdbPagingTests(idbMemoryContext);
}

var pagingTestStore = SdbStoreRef<int, SdbModel>('paging_test');
var pagingTestIndex = pagingTestStore.index<String>('name');

/// Match everything, only there to force the dart cursor path: an
/// implementation able to page natively (sql LIMIT/OFFSET) is only allowed to
/// do so when there is no filter, so the same query with and without this
/// filter must give the exact same records.
final _matchAllFilter = SdbFilter.custom((snapshot) => true);

/// Paging tests: offset and limit must give the same records whether the
/// implementation applies them natively or by walking a cursor.
void idbSdbPagingTests(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);

  group('sdb_paging', () {
    late SdbDatabase db;
    var dbName = 'sdb_paging.db';
    const count = 20;

    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              pagingTestStore.schema(
                indexes: [pagingTestIndex.schema(keyPath: 'name')],
              ),
            ],
          ),
        ),
      );
      await db.inStoreTransaction(
        pagingTestStore,
        SdbTransactionMode.readWrite,
        (txn) async {
          for (var i = 0; i < count; i++) {
            await pagingTestStore.record(i).put(txn, {
              'name': 'name_${i.toString().padLeft(2, '0')}',
              'value': i,
            });
          }
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    /// All the (offset, limit, descending) combinations worth checking.
    var cases = <({int? offset, int? limit, bool? descending})>[
      (offset: null, limit: null, descending: null),
      (offset: 0, limit: 5, descending: null),
      (offset: 3, limit: 5, descending: null),
      (offset: 3, limit: null, descending: null),
      (offset: null, limit: 5, descending: null),
      (offset: 18, limit: 5, descending: null),
      (offset: 20, limit: 5, descending: null),
      (offset: 25, limit: 5, descending: null),
      (offset: 0, limit: 100, descending: null),
      (offset: 3, limit: 5, descending: true),
      (offset: 18, limit: 5, descending: true),
      (offset: 3, limit: null, descending: true),
    ];

    test('store records paged like the cursor', () async {
      for (var c in cases) {
        var reason =
            'offset ${c.offset} limit ${c.limit} '
            'descending ${c.descending}';
        var paged = await pagingTestStore.findRecords(
          db,
          options: SdbFindOptions(
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
          ),
        );
        var walked = await pagingTestStore.findRecords(
          db,
          options: SdbFindOptions(
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
            filter: _matchAllFilter,
          ),
        );
        expect(paged.keys, walked.keys, reason: reason);
        expect(
          paged.map((e) => e.value['value']),
          walked.map((e) => e.value['value']),
          reason: reason,
        );
      }
    });

    test('store keys paged like the records', () async {
      for (var c in cases) {
        var reason =
            'offset ${c.offset} limit ${c.limit} '
            'descending ${c.descending}';
        var options = SdbFindOptions<int>(
          offset: c.offset,
          limit: c.limit,
          descending: c.descending,
        );
        var keys = await pagingTestStore.findRecordKeys(db, options: options);
        var records = await pagingTestStore.findRecords(db, options: options);
        expect(keys.keys, records.keys, reason: reason);
      }
    });

    test('store records paged within boundaries', () async {
      // name_05 (key 5) and up.
      var boundaries = SdbBoundaries<int>(
        pagingTestStore.lowerBoundary(5),
        null,
      );
      for (var c in cases) {
        var reason =
            'offset ${c.offset} limit ${c.limit} '
            'descending ${c.descending}';
        var paged = await pagingTestStore.findRecords(
          db,
          options: SdbFindOptions(
            boundaries: boundaries,
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
          ),
        );
        var walked = await pagingTestStore.findRecords(
          db,
          options: SdbFindOptions(
            boundaries: boundaries,
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
            filter: _matchAllFilter,
          ),
        );
        expect(paged.keys, walked.keys, reason: reason);
      }
    });

    test('index records paged like the cursor', () async {
      for (var c in cases) {
        var reason =
            'offset ${c.offset} limit ${c.limit} '
            'descending ${c.descending}';
        var paged = await pagingTestIndex.findRecords(
          db,
          options: SdbFindOptions(
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
          ),
        );
        var walked = await pagingTestIndex.findRecords(
          db,
          options: SdbFindOptions(
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
            filter: _matchAllFilter,
          ),
        );
        expect(paged.keys, walked.keys, reason: reason);
        expect(
          paged.map((e) => e.indexKey),
          walked.map((e) => e.indexKey),
          reason: reason,
        );
      }
    });

    test('index keys paged like the records', () async {
      for (var c in cases) {
        var reason =
            'offset ${c.offset} limit ${c.limit} '
            'descending ${c.descending}';
        var options = SdbFindOptions<String>(
          offset: c.offset,
          limit: c.limit,
          descending: c.descending,
        );
        var keys = await pagingTestIndex.findRecordKeys(db, options: options);
        var records = await pagingTestIndex.findRecords(db, options: options);
        expect(keys.keys, records.keys, reason: reason);
        expect(
          keys.map((e) => e.indexKey),
          records.map((e) => e.indexKey),
          reason: reason,
        );
      }
    });

    test('index records paged within boundaries', () async {
      var boundaries = SdbBoundaries<String>(
        pagingTestIndex.lowerBoundary('name_05'),
        null,
      );
      for (var c in cases) {
        var reason =
            'offset ${c.offset} limit ${c.limit} '
            'descending ${c.descending}';
        var paged = await pagingTestIndex.findRecords(
          db,
          options: SdbFindOptions(
            boundaries: boundaries,
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
          ),
        );
        var walked = await pagingTestIndex.findRecords(
          db,
          options: SdbFindOptions(
            boundaries: boundaries,
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
            filter: _matchAllFilter,
          ),
        );
        expect(paged.keys, walked.keys, reason: reason);
      }
    });
  });
}
