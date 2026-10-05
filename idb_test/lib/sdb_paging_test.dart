import 'package:idb_shim/sdb.dart';

import 'idb_test_common.dart';
import 'sdb_test.dart';

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

/// Paging tests on an idb factory.
void idbSdbPagingTests(TestContext ctx) {
  sdbPagingTests(SdbTestContext(sdbFactoryFromIdb(ctx.factory)));
}

/// Paging tests: offset and limit must give the same records whether the
/// implementation applies them natively or by walking a cursor.
void sdbPagingTests(SdbTestContext ctx) {
  var factory = ctx.factory;

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

  // More records than one read chunk, so that an implementation reading them
  // chunk by chunk has to cross a chunk boundary.
  group('sdb_paging_iterate', () {
    late SdbDatabase db;
    var dbName = 'sdb_paging_iterate.db';
    const count = 450;

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
              'name': 'name_${i.toString().padLeft(3, '0')}',
              'value': i,
            });
          }
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> storeIterate({
      int? offset,
      int? limit,
      bool? descending,
      SdbFilter? filter,
      int? stopAfter,
    }) async {
      var visited = 0;
      await pagingTestStore.iterate(
        db,
        options: SdbFindOptions(
          offset: offset,
          limit: limit,
          descending: descending,
          filter: filter,
        ),
        onRow: (row) {
          visited++;
          return stopAfter == null || visited < stopAfter;
        },
      );
      return visited;
    }

    Future<int> indexIterate({
      int? offset,
      int? limit,
      bool? descending,
      SdbFilter? filter,
      int? stopAfter,
    }) async {
      var visited = 0;
      await pagingTestIndex.iterate(
        db,
        options: SdbFindOptions(
          offset: offset,
          limit: limit,
          descending: descending,
          filter: filter,
        ),
        onRow: (row) {
          visited++;
          return stopAfter == null || visited < stopAfter;
        },
      );
      return visited;
    }

    test('store iterate visits every record across chunks', () async {
      expect(await storeIterate(), count);
    });

    test('store iterate stops early across a chunk', () async {
      expect(await storeIterate(stopAfter: 250), 250);
      expect(await storeIterate(stopAfter: 1), 1);
      expect(await storeIterate(stopAfter: count + 10), count);
    });

    test('store iterate offset and limit across chunks', () async {
      expect(await storeIterate(offset: 150, limit: 200), 200);
      expect(await storeIterate(offset: 0, limit: 250), 250);
      expect(await storeIterate(offset: 400, limit: 200), 50);
      expect(await storeIterate(offset: count, limit: 10), 0);
      expect(await storeIterate(offset: 250), 200);
      expect(await storeIterate(limit: 450), 450);
      expect(await storeIterate(limit: 1000), 450);
    });

    test('store iterate visits like the cursor', () async {
      for (var c in [
        (offset: null, limit: null, descending: null),
        (offset: 150, limit: 200, descending: null),
        (offset: 400, limit: 200, descending: null),
        (offset: 250, limit: null, descending: null),
        (offset: 150, limit: 200, descending: true),
      ]) {
        var reason =
            'offset ${c.offset} limit ${c.limit} descending ${c.descending}';
        var paged = await storeIterate(
          offset: c.offset,
          limit: c.limit,
          descending: c.descending,
        );
        var walked = await storeIterate(
          offset: c.offset,
          limit: c.limit,
          descending: c.descending,
          filter: _matchAllFilter,
        );
        expect(paged, walked, reason: reason);
      }
    });

    test('store iterate updates every record once', () async {
      var visited = 0;
      await pagingTestStore.iterate(
        db,
        mode: SdbTransactionMode.readWrite,
        onRow: (row) async {
          visited++;
          // Keep the name (and so the primary key order and the index key)
          // and mark the record.
          await row.update({'name': 'kept', 'marked': true});
          return true;
        },
      );
      expect(visited, count);
      var records = await pagingTestStore.findRecords(db);
      expect(records.length, count);
      expect(records.where((r) => r.value['marked'] == true).length, count);
    });

    test('index iterate visits every record across chunks', () async {
      expect(await indexIterate(), count);
    });

    test('index iterate stops early across a chunk', () async {
      expect(await indexIterate(stopAfter: 250), 250);
    });

    test('index iterate visits like the cursor', () async {
      for (var c in [
        (offset: null, limit: null, descending: null),
        (offset: 150, limit: 200, descending: null),
        (offset: 400, limit: 200, descending: null),
        (offset: 150, limit: 200, descending: true),
      ]) {
        var reason =
            'offset ${c.offset} limit ${c.limit} descending ${c.descending}';
        var paged = await indexIterate(
          offset: c.offset,
          limit: c.limit,
          descending: c.descending,
        );
        var walked = await indexIterate(
          offset: c.offset,
          limit: c.limit,
          descending: c.descending,
          filter: _matchAllFilter,
        );
        expect(paged, walked, reason: reason);
      }
    });

    test('store streamRecords paged like the cursor', () async {
      for (var c in [
        (offset: null, limit: null, descending: null),
        (offset: 150, limit: 200, descending: null),
        (offset: 400, limit: 200, descending: null),
        (offset: 250, limit: null, descending: null),
        (offset: 150, limit: 200, descending: true),
      ]) {
        var reason =
            'offset ${c.offset} limit ${c.limit} descending ${c.descending}';
        var paged = await pagingTestStore
            .streamRecords(
              db,
              options: SdbFindOptions<int>(
                offset: c.offset,
                limit: c.limit,
                descending: c.descending,
              ),
            )
            .toList();
        var walked = await pagingTestStore
            .streamRecords(
              db,
              options: SdbFindOptions<int>(
                offset: c.offset,
                limit: c.limit,
                descending: c.descending,
                filter: _matchAllFilter,
              ),
            )
            .toList();
        expect(paged.keys, walked.keys, reason: reason);
      }
    });

    test('store streamRecords stops reading when unsubscribed', () async {
      var read = 0;
      await for (var _ in pagingTestStore.streamRecords(db)) {
        read++;
        if (read == 12) {
          break;
        }
      }
      expect(read, 12);
    });

    test('index streamRecords paged like the cursor', () async {
      for (var c in [
        (offset: null, limit: null, descending: null),
        (offset: 150, limit: 200, descending: null),
        (offset: 400, limit: 200, descending: null),
        (offset: 150, limit: 200, descending: true),
      ]) {
        var reason =
            'offset ${c.offset} limit ${c.limit} descending ${c.descending}';
        var paged = await pagingTestIndex
            .streamRecords(
              db,
              options: SdbFindOptions<String>(
                offset: c.offset,
                limit: c.limit,
                descending: c.descending,
              ),
            )
            .toList();
        var walked = await pagingTestIndex
            .streamRecords(
              db,
              options: SdbFindOptions<String>(
                offset: c.offset,
                limit: c.limit,
                descending: c.descending,
                filter: _matchAllFilter,
              ),
            )
            .toList();
        expect(paged.keys, walked.keys, reason: reason);
      }
    });

    test('store delete with offset and limit across chunks', () async {
      await pagingTestStore.delete(
        db,
        options: SdbFindOptions(offset: 50, limit: 250),
      );
      var left = await pagingTestStore.findRecordKeys(db);
      expect(left.length, count - 250);
      expect(left.keys.take(50), List.generate(50, (i) => i));
      expect(left.keys.skip(50).first, 300);
    });

    test('store delete every record across chunks', () async {
      await pagingTestStore.delete(db, options: SdbFindOptions(limit: count));
      expect(await pagingTestStore.count(db), 0);
    });

    test('index delete with offset and limit across chunks', () async {
      await pagingTestIndex.delete(
        db,
        options: SdbFindOptions(offset: 50, limit: 250),
      );
      var left = await pagingTestStore.findRecordKeys(db);
      expect(left.length, count - 250);
      expect(left.keys.take(50), List.generate(50, (i) => i));
      expect(left.keys.skip(50).first, 300);
    });

    test('index delete every record across chunks', () async {
      await pagingTestIndex.delete(db, options: SdbFindOptions(limit: count));
      expect(await pagingTestStore.count(db), 0);
    });

    test('index iterate updates every record once', () async {
      var visited = 0;
      await pagingTestIndex.iterate(
        db,
        mode: SdbTransactionMode.readWrite,
        onRow: (row) async {
          visited++;
          // The index key must not change, else the record moves while it is
          // being iterated.
          var index = visited - 1;
          await row.update({
            'name': 'name_${index.toString().padLeft(3, '0')}',
            'marked': true,
          });
          return true;
        },
      );
      expect(visited, count);
      var records = await pagingTestStore.findRecords(db);
      expect(records.where((r) => r.value['marked'] == true).length, count);
    });
  });
}
