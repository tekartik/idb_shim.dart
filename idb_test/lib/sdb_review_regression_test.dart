// Regression tests of the 2026-11-09 review (sdb layer, the same behavior is
// expected from every idb implementation).
library;

import 'package:idb_shim/sdb.dart';

import 'idb_test_common.dart';
import 'sdb_test.dart';

// so that this can be run directly
void main() {
  idbSdbReviewRegressionTests(idbMemoryContext);
}

var _store = SdbStoreRef<int, SdbModel>('s');
var _inlineStore = SdbStoreRef<int, SdbModel>('inline');
var _bookStore = SdbStoreRef<int, SdbModel>('book');
var _authorStore = SdbStoreRef<int, SdbModel>('author');

/// Review regression tests on an idb factory.
void idbSdbReviewRegressionTests(TestContext ctx) {
  sdbReviewRegressionTests(SdbTestContext(sdbFactoryFromIdb(ctx.factory)));
}

/// Review regression tests on an idb based sdb factory.
void sdbReviewRegressionTests(SdbTestContext ctx) {
  var factory = ctx.factory;

  group('sdb_review_regression', () {
    late SdbDatabase db;
    var dbName = 'sdb_review_regression.db';
    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              _store.schema(autoIncrement: true),
              _inlineStore.schema(keyPath: SdbKeyPath.single('id')),
              _bookStore.schema(),
              _authorStore.schema(),
            ],
          ),
        ),
      );
    });
    tearDown(() async {
      await db.close();
    });

    test('the error of a failed write reaches the caller', () async {
      // A missing inline key, the transaction is aborted.
      try {
        await _inlineStore.put(db, {'a': 1});
        fail('should fail');
      } on DatabaseError catch (_) {}
      try {
        await db.inStoreTransaction(
          _inlineStore,
          SdbTransactionMode.readWrite,
          (txn) => txn.txnStore.put(null, {'a': 1}),
        );
        fail('should fail');
      } on DatabaseError catch (_) {}
    });

    test('inline put of an existing record is an update', () async {
      await _inlineStore.put(db, {'id': 1, 'v': 1});
      var changes = <SdbRecordChange<int, SdbModel>>[];
      void listener(
        SdbTransaction txn,
        List<SdbRecordChange<int, SdbModel>> list,
      ) {
        changes.addAll(list);
      }

      _inlineStore.addOnChangesListener(db, listener);
      try {
        await _inlineStore.put(db, {'id': 1, 'v': 2});
        expect(changes, hasLength(1));
        expect(changes.first.oldValue, {'id': 1, 'v': 1});
        expect(changes.first.isUpdate, isTrue);
        changes.clear();
        await _inlineStore.put(db, {'id': 2, 'v': 1});
        expect(changes.first.isAdd, isTrue);
      } finally {
        _inlineStore.removeOnChangesListener(db, listener);
      }
    });

    test('filters on nested fields', () async {
      await _store.record(1).put(db, {
        'a': {
          'b': 2,
          'list': [1, 2],
        },
      });
      await _store.record(2).put(db, {'a': 1});
      Future<List<int>> keys(SdbFilter filter) async =>
          (await _store.findRecordKeys(
            db,
            options: SdbFindOptions(filter: filter),
          )).map((record) => record.key).toList();
      expect(await keys(SdbFilter.equals('a.b', 2)), [1]);
      expect(await keys(SdbFilter.greaterThan('a.b', 1)), [1]);
      expect(await keys(SdbFilter.lessThan('a.b', 3)), [1]);
      expect(await keys(SdbFilter.notNull('a.b')), [1]);
      expect(await keys(SdbFilter.isNull('a.b')), [2]);
      expect(await keys(SdbFilter.inList('a.b', [2])), [1]);
      expect(await keys(SdbFilter.arrayContains('a.list', 1)), [1]);
      // Top level fields still work.
      expect(await keys(SdbFilter.equals('a', 1)), [2]);
      expect(await keys(SdbFilter.greaterThan('a', 0)), [2]);
    });

    test('join with limit 0', () async {
      await _authorStore.record(1).put(db, {'name': 'a1'});
      await _bookStore.record(1).put(db, {'authorId': 1});
      await _bookStore.record(2).put(db, {'authorId': 1});
      for (var joinOptions in [
        const SdbJoinFindOptions(),
        const SdbJoinFindOptions(inner: true),
        const SdbJoinFindOptions(distinct: true),
      ]) {
        var rows = await _bookStore.findJoinRows(
          db,
          target: _authorStore.asJoinTarget,
          joinKeyPath: 'authorId',
          options: SdbFindOptions(limit: 0),
          joinOptions: joinOptions,
        );
        expect(rows, isEmpty, reason: '$joinOptions');
        rows = await _bookStore.findJoinRows(
          db,
          target: _authorStore.asJoinTarget,
          joinKeyPath: 'authorId',
          options: SdbFindOptions(limit: 1),
          joinOptions: joinOptions,
        );
        expect(rows, hasLength(1), reason: '$joinOptions');
      }
    });
  });
}
