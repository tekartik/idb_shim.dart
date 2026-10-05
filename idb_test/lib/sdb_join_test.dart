import 'package:idb_shim/sdb.dart';

import 'idb_test_common.dart';
import 'sdb_test.dart';

void main() {
  idbSdbJoinTests(idbMemoryContext);
}

/// Joined (parent) store.
var joinParentStore = SdbStoreRef<int, SdbModel>('join_parent');

/// Iterated (child) store, `parentId` referencing [joinParentStore].
var joinChildStore = SdbStoreRef<int, SdbModel>('join_child');

/// Same as [joinChildStore], with an index on the join key path: an
/// implementation able to join natively can then read the join key from the
/// index instead of from the stored value.
var joinIndexedChildStore = SdbStoreRef<int, SdbModel>('join_indexed_child');

/// The index on the join key path of [joinIndexedChildStore].
var joinChildParentIndex = joinIndexedChildStore.index<int>('parentId');

/// Match everything, only there to force the dart path: an implementation able
/// to join natively is only allowed to do so when there is no filter, so the
/// same join with and without this filter must give the exact same rows.
final _matchAllFilter = SdbFilter.custom((snapshot) => true);

/// Join tests on an idb factory.
void idbSdbJoinTests(TestContext ctx) {
  sdbJoinTests(SdbTestContext(sdbFactoryFromIdb(ctx.factory)));
}

/// Join tests: a join must give the same rows whether the implementation
/// resolves it natively (from an index or from the stored value) or by reading
/// the joined records one by one.
void sdbJoinTests(SdbTestContext ctx) {
  var factory = ctx.factory;

  group('sdb_join', () {
    late SdbDatabase db;
    var dbName = 'sdb_join.db';

    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              joinParentStore.schema(),
              joinChildStore.schema(),
              joinIndexedChildStore.schema(
                indexes: [joinChildParentIndex.schema(keyPath: 'parentId')],
              ),
            ],
          ),
        ),
      );
      await db.inStoresTransaction(
        [joinParentStore, joinChildStore, joinIndexedChildStore],
        SdbTransactionMode.readWrite,
        (txn) async {
          for (var i = 1; i <= 3; i++) {
            await joinParentStore.record(i).put(txn, {'label': 'p$i'});
          }
          // 2 children on parent 1, 1 on parent 2, 1 without a parent id, 1 on
          // a parent that does not exist, 1 on parent 3.
          var children = <int, SdbModel>{
            1: {'name': 'c1', 'parentId': 1},
            2: {'name': 'c2', 'parentId': 1},
            3: {'name': 'c3', 'parentId': 2},
            4: {'name': 'c4'},
            5: {'name': 'c5', 'parentId': 9},
            6: {'name': 'c6', 'parentId': 3},
          };
          for (var entry in children.entries) {
            await joinChildStore.record(entry.key).put(txn, entry.value);
            await joinIndexedChildStore.record(entry.key).put(txn, entry.value);
          }
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    /// Every combination worth checking, run on both child stores and both
    /// ways (see [_matchAllFilter]).
    var cases =
        <
          ({
            String name,
            bool? distinct,
            bool? inner,
            int? offset,
            int? limit,
            bool? descending,
            List<String> expected,
          })
        >[
          (
            name: 'left join',
            distinct: null,
            inner: null,
            offset: null,
            limit: null,
            descending: null,
            expected: ['1->1', '2->1', '3->2', '4->null', '5->null', '6->3'],
          ),
          (
            name: 'inner join',
            distinct: null,
            inner: true,
            offset: null,
            limit: null,
            descending: null,
            expected: ['1->1', '2->1', '3->2', '6->3'],
          ),
          (
            name: 'distinct',
            distinct: true,
            inner: null,
            offset: null,
            limit: null,
            descending: null,
            expected: ['1->1', '3->2', '4->null', '5->null', '6->3'],
          ),
          (
            name: 'distinct inner',
            distinct: true,
            inner: true,
            offset: null,
            limit: null,
            descending: null,
            expected: ['1->1', '3->2', '6->3'],
          ),
          (
            name: 'offset limit',
            distinct: null,
            inner: null,
            offset: 2,
            limit: 3,
            descending: null,
            expected: ['3->2', '4->null', '5->null'],
          ),
          (
            // The offset and the limit apply to the rows handed out, i.e. after
            // `inner` dropped any.
            name: 'offset limit inner',
            distinct: null,
            inner: true,
            offset: 1,
            limit: 2,
            descending: null,
            expected: ['2->1', '3->2'],
          ),
          (
            name: 'offset limit distinct',
            distinct: true,
            inner: null,
            offset: 1,
            limit: 2,
            descending: null,
            expected: ['3->2', '4->null'],
          ),
          (
            name: 'offset past the end',
            distinct: null,
            inner: null,
            offset: 10,
            limit: 3,
            descending: null,
            expected: <String>[],
          ),
          (
            name: 'descending',
            distinct: null,
            inner: null,
            offset: null,
            limit: null,
            descending: true,
            expected: ['6->3', '5->null', '4->null', '3->2', '2->1', '1->1'],
          ),
          (
            name: 'descending offset limit inner',
            distinct: null,
            inner: true,
            offset: 1,
            limit: 2,
            descending: true,
            expected: ['3->2', '2->1'],
          ),
        ];

    /// The join key path is indexed on [joinIndexedChildStore] only, so the
    /// same cases run through both native paths.
    for (var childStore in [joinChildStore, joinIndexedChildStore]) {
      var indexed = childStore == joinIndexedChildStore;
      var suffix = indexed ? ' (indexed)' : '';

      /// '<child key>-><parent key>' for each row, so that a failure reads
      /// well.
      Future<List<String>> join({
        bool? distinct,
        bool? inner,
        int? offset,
        int? limit,
        bool? descending,
        SdbFilter? filter,
        int? chunkSize,
      }) async {
        var rows = <String>[];
        await childStore.joinIterate<int, SdbModel>(
          db,
          target: joinParentStore.asJoinTarget,
          joinKeyPath: 'parentId',
          options: SdbFindOptions(
            offset: offset,
            limit: limit,
            descending: descending,
            filter: filter,
          ),
          joinOptions: SdbJoinFindOptions(
            distinct: distinct,
            inner: inner,
            chunkSize: chunkSize,
          ),
          onRow: (row) {
            rows.add('${row.record.key}->${row.joinedRecord?.key}');
            return true;
          },
        );
        return rows;
      }

      for (var c in cases) {
        test('${c.name}$suffix', () async {
          var rows = await join(
            distinct: c.distinct,
            inner: c.inner,
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
          );
          expect(rows, c.expected);

          // Same join, forced through the dart path.
          var walked = await join(
            distinct: c.distinct,
            inner: c.inner,
            offset: c.offset,
            limit: c.limit,
            descending: c.descending,
            filter: _matchAllFilter,
          );
          expect(walked, c.expected, reason: 'dart path');
        });
      }

      test('chunk size smaller than the result$suffix', () async {
        // Forces several chunks through an implementation able to join
        // natively.
        expect(await join(chunkSize: 2), [
          '1->1',
          '2->1',
          '3->2',
          '4->null',
          '5->null',
          '6->3',
        ]);
        expect(await join(chunkSize: 2, inner: true), [
          '1->1',
          '2->1',
          '3->2',
          '6->3',
        ]);
      });

      test('joined values$suffix', () async {
        var labels = <String?>[];
        await childStore.joinIterate<int, SdbModel>(
          db,
          target: joinParentStore.asJoinTarget,
          joinKeyPath: 'parentId',
          onRow: (row) {
            labels.add(row.joinedRecord?.value['label'] as String?);
            return true;
          },
        );
        expect(labels, ['p1', 'p1', 'p2', null, null, 'p3']);
      });

      test('source values$suffix', () async {
        var names = <String?>[];
        await childStore.joinIterate<int, SdbModel>(
          db,
          target: joinParentStore.asJoinTarget,
          joinKeyPath: 'parentId',
          onRow: (row) {
            names.add(row.record.value['name'] as String?);
            return true;
          },
        );
        expect(names, ['c1', 'c2', 'c3', 'c4', 'c5', 'c6']);
      });

      test('join key$suffix', () async {
        var keys = <int?>[];
        await childStore.joinIterate<int, SdbModel>(
          db,
          target: joinParentStore.asJoinTarget,
          joinKeyPath: 'parentId',
          onRow: (row) {
            keys.add(row.joinKey as int?);
            return true;
          },
        );
        expect(keys, [1, 1, 2, null, 9, 3]);
      });

      test('stop iterating$suffix', () async {
        var rows = <String>[];
        await childStore.joinIterate<int, SdbModel>(
          db,
          target: joinParentStore.asJoinTarget,
          joinKeyPath: 'parentId',
          onRow: (row) {
            rows.add('${row.record.key}->${row.joinedRecord?.key}');
            return rows.length < 2;
          },
        );
        expect(rows, ['1->1', '2->1']);
      });

      test('in an existing transaction$suffix', () async {
        var rows = <String>[];
        await db.inStoresTransaction(
          [childStore, joinParentStore],
          SdbTransactionMode.readOnly,
          (txn) async {
            await childStore.joinIterate<int, SdbModel>(
              txn,
              target: joinParentStore.asJoinTarget,
              joinKeyPath: 'parentId',
              joinOptions: const SdbJoinFindOptions(inner: true),
              onRow: (row) {
                rows.add('${row.record.key}->${row.joinedRecord?.key}');
                return true;
              },
            );
          },
        );
        expect(rows, ['1->1', '2->1', '3->2', '6->3']);
      });

      test('boundaries$suffix', () async {
        var rows = <String>[];
        await childStore.joinIterate<int, SdbModel>(
          db,
          target: joinParentStore.asJoinTarget,
          joinKeyPath: 'parentId',
          options: SdbFindOptions(
            boundaries: SdbBoundaries(
              childStore.lowerBoundary(2),
              childStore.upperBoundary(5),
            ),
          ),
          onRow: (row) {
            rows.add('${row.record.key}->${row.joinedRecord?.key}');
            return true;
          },
        );
        expect(rows, ['2->1', '3->2', '4->null']);
      });

      test('findJoinRows$suffix', () async {
        var rows = await childStore.findJoinRows<int, SdbModel>(
          db,
          target: joinParentStore.asJoinTarget,
          joinKeyPath: 'parentId',
          joinOptions: const SdbJoinFindOptions(inner: true),
        );
        expect(rows.map((row) => row.record.key).toList(), [1, 2, 3, 6]);
        expect(rows.map((row) => row.joinedRecord!.key).toList(), [1, 1, 2, 3]);
      });

      test('findJoinRecords hands out the source records$suffix', () async {
        Future<List<int>> sources({bool? inner, SdbFilter? filter}) async {
          var records = await childStore.findJoinRecords<int, SdbModel>(
            db,
            target: joinParentStore.asJoinTarget,
            joinKeyPath: 'parentId',
            options: SdbFindOptions(filter: filter),
            joinOptions: SdbJoinFindOptions(inner: inner),
          );
          return records.map((record) => record.key).toList();
        }

        // A left join hands out every source record...
        expect(await sources(), [1, 2, 3, 4, 5, 6]);
        expect(await sources(filter: _matchAllFilter), [
          1,
          2,
          3,
          4,
          5,
          6,
        ], reason: 'dart path');
        // ...and a semi join only the ones that match something.
        expect(await sources(inner: true), [1, 2, 3, 6]);
        expect(await sources(inner: true, filter: _matchAllFilter), [
          1,
          2,
          3,
          6,
        ], reason: 'dart path');
      });

      test('findJoinedRecords hands out the joined records$suffix', () async {
        Future<List<int>> joined({bool? distinct, SdbFilter? filter}) async {
          var records = await childStore.findJoinedRecords<int, SdbModel>(
            db,
            target: joinParentStore.asJoinTarget,
            joinKeyPath: 'parentId',
            options: SdbFindOptions(filter: filter),
            joinOptions: SdbJoinFindOptions(distinct: distinct),
          );
          return records.map((record) => record.key).toList();
        }

        // Always inner: the children matching nothing hand out nothing.
        expect(await joined(), [1, 1, 2, 3]);
        expect(await joined(filter: _matchAllFilter), [
          1,
          1,
          2,
          3,
        ], reason: 'dart path');
        // The parents actually referenced, each one once.
        expect(await joined(distinct: true), [1, 2, 3]);
        expect(await joined(distinct: true, filter: _matchAllFilter), [
          1,
          2,
          3,
        ], reason: 'dart path');
      });

      test('joinCount$suffix', () async {
        Future<int> count({bool? distinct, bool? inner}) =>
            childStore.joinCount<int, SdbModel>(
              db,
              target: joinParentStore.asJoinTarget,
              joinKeyPath: 'parentId',
              joinOptions: SdbJoinFindOptions(distinct: distinct, inner: inner),
            );
        expect(await count(), 6);
        expect(await count(inner: true), 4);
        expect(await count(distinct: true), 5);
        expect(await count(distinct: true, inner: true), 3);
      });

      test('joined record updated during the iteration$suffix', () async {
        // The index of the iterated store is on the join key, a write on the
        // joined store must be seen by the join whatever path is taken.
        await joinParentStore.record(9).put(db, {'label': 'p9'});
        var rows = <String>[];
        await childStore.joinIterate<int, SdbModel>(
          db,
          target: joinParentStore.asJoinTarget,
          joinKeyPath: 'parentId',
          onRow: (row) {
            rows.add('${row.record.key}->${row.joinedRecord?.key}');
            return true;
          },
        );
        expect(rows, ['1->1', '2->1', '3->2', '4->null', '5->9', '6->3']);
      });

      if (indexed) {
        test('index key kept in sync with the value$suffix', () async {
          // The join reads the key from the index, it must follow a record
          // being updated, deleted, or added.
          await childStore.record(4).put(db, {'name': 'c4', 'parentId': 2});
          await childStore.record(1).put(db, {'name': 'c1'});
          await childStore.record(2).delete(db);
          await childStore.record(7).put(db, {'name': 'c7', 'parentId': 3});
          var rows = <String>[];
          await childStore.joinIterate<int, SdbModel>(
            db,
            target: joinParentStore.asJoinTarget,
            joinKeyPath: 'parentId',
            onRow: (row) {
              rows.add('${row.record.key}->${row.joinedRecord?.key}');
              return true;
            },
          );
          expect(rows, ['1->null', '3->2', '4->2', '5->null', '6->3', '7->3']);
        });
      }
    }
  });

  group('sdb_join_one_to_many', () {
    late SdbDatabase db;
    var dbName = 'sdb_join_one_to_many.db';
    var postStore = SdbStoreRef<int, SdbModel>('post');
    var commentStore = SdbStoreRef<int, SdbModel>('comment');
    var commentPostIndex = commentStore.index<int>('postId');

    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              postStore.schema(),
              commentStore.schema(
                indexes: [commentPostIndex.schema(keyPath: 'postId')],
              ),
            ],
          ),
        ),
      );
      await db.inStoresTransaction(
        [postStore, commentStore],
        SdbTransactionMode.readWrite,
        (txn) async {
          for (var i = 1; i <= 3; i++) {
            await postStore.record(i).put(txn, {'title': 'post$i'});
          }
          // 2 comments on post 1, 1 on post 2, 1 with no post, 1 on a post that
          // does not exist. Post 3 has none.
          var comments = <int, SdbModel>{
            11: {'text': 'c11', 'postId': 1},
            12: {'text': 'c12', 'postId': 1},
            13: {'text': 'c13', 'postId': 2},
            14: {'text': 'c14'},
            15: {'text': 'c15', 'postId': 9},
          };
          for (var entry in comments.entries) {
            await commentStore.record(entry.key).put(txn, entry.value);
          }
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    /// From the parent side: each post with its comments, matched against the
    /// index on the comment side, the post primary key being the join key.
    Future<List<String>> postsWithComments({
      bool? inner,
      bool? distinct,
      int? offset,
      int? limit,
      SdbFilter? filter,
      int? chunkSize,
    }) async {
      var rows = <String>[];
      await postStore.joinIterate<int, SdbModel>(
        db,
        target: commentPostIndex.asJoinTarget,
        // No key path: the post primary key is the join key.
        options: SdbFindOptions(offset: offset, limit: limit, filter: filter),
        joinOptions: SdbJoinFindOptions(
          inner: inner,
          distinct: distinct,
          chunkSize: chunkSize,
        ),
        onRow: (row) {
          rows.add('${row.record.key}->${row.joinedRecord?.key}');
          return true;
        },
      );
      return rows;
    }

    /// From the child side: each comment with its post, iterating the index so
    /// that the comments of a post are consecutive.
    Future<List<String>> commentsWithPost({
      bool? inner,
      bool? distinct,
      int? offset,
      int? limit,
      bool? descending,
      SdbBoundaries<int>? boundaries,
      SdbFilter? filter,
      int? chunkSize,
    }) async {
      var rows = <String>[];
      await commentPostIndex.joinIterate<int, SdbModel>(
        db,
        target: postStore.asJoinTarget,
        options: SdbFindOptions(
          offset: offset,
          limit: limit,
          descending: descending,
          boundaries: boundaries,
          filter: filter,
        ),
        joinOptions: SdbJoinFindOptions(
          inner: inner,
          distinct: distinct,
          chunkSize: chunkSize,
        ),
        onRow: (row) {
          rows.add('${row.record.key}->${row.joinedRecord?.key}');
          return true;
        },
      );
      return rows;
    }

    /// Runs [run] both ways: natively, and forced through the dart path.
    Future<void> bothWays(
      Future<List<String>> Function({SdbFilter? filter}) run,
      List<String> expected,
    ) async {
      expect(await run(), expected);
      expect(await run(filter: _matchAllFilter), expected, reason: 'dart path');
    }

    test('one to many from the parent side', () async {
      // Post 1 has two comments, so it gives two rows; post 3 has none, so it
      // gives the null side of a left join.
      await bothWays(({filter}) => postsWithComments(filter: filter), [
        '1->11',
        '1->12',
        '2->13',
        '3->null',
      ]);
    });

    test('one to many, inner', () async {
      await bothWays(
        ({filter}) => postsWithComments(inner: true, filter: filter),
        ['1->11', '1->12', '2->13'],
      );
    });

    test(
      'one to many, distinct keeps every match of the first record',
      () async {
        // Each post is its own join key here, so distinct changes nothing.
        await bothWays(
          ({filter}) => postsWithComments(distinct: true, filter: filter),
          ['1->11', '1->12', '2->13', '3->null'],
        );
      },
    );

    test('one to many, the source records collapse', () async {
      // The rows of one post collapse into one record, however many comments
      // it has: post 1 has two, and is handed out once.
      Future<List<int>> posts({bool? inner, SdbFilter? filter}) async {
        var records = await postStore.findJoinRecords<int, SdbModel>(
          db,
          target: commentPostIndex.asJoinTarget,
          options: SdbFindOptions(filter: filter),
          joinOptions: SdbJoinFindOptions(inner: inner),
        );
        return records.map((record) => record.key).toList();
      }

      expect(await posts(), [1, 2, 3]);
      expect(await posts(filter: _matchAllFilter), [
        1,
        2,
        3,
      ], reason: 'dart path');
      // A semi join: only the posts that do have a comment.
      expect(await posts(inner: true), [1, 2]);
      expect(await posts(inner: true, filter: _matchAllFilter), [
        1,
        2,
      ], reason: 'dart path');
    });

    test('one to many, the source records collapse with offset', () async {
      // The offset and the limit apply to the collapsed records.
      Future<List<int>> posts({SdbFilter? filter}) async {
        var records = await postStore.findJoinRecords<int, SdbModel>(
          db,
          target: commentPostIndex.asJoinTarget,
          options: SdbFindOptions(offset: 1, limit: 1, filter: filter),
        );
        return records.map((record) => record.key).toList();
      }

      expect(await posts(), [2]);
      expect(await posts(filter: _matchAllFilter), [2], reason: 'dart path');
    });

    test('one to many, offset and limit after the join', () async {
      await bothWays(
        ({filter}) => postsWithComments(offset: 1, limit: 2, filter: filter),
        ['1->12', '2->13'],
      );
    });

    test('one to many, chunk by chunk', () async {
      expect(await postsWithComments(chunkSize: 2), [
        '1->11',
        '1->12',
        '2->13',
        '3->null',
      ]);
    });

    test('index source, each comment with its post', () async {
      // Ordered by post id then comment id; the comment with no post id is
      // not in the index at all.
      await bothWays(({filter}) => commentsWithPost(filter: filter), [
        '11->1',
        '12->1',
        '13->2',
        '15->null',
      ]);
    });

    test('index source, inner', () async {
      await bothWays(
        ({filter}) => commentsWithPost(inner: true, filter: filter),
        ['11->1', '12->1', '13->2'],
      );
    });

    test('index source, distinct gives one row per index key', () async {
      await bothWays(
        ({filter}) => commentsWithPost(distinct: true, filter: filter),
        ['11->1', '13->2', '15->null'],
      );
    });

    test('index source, the joined records only', () async {
      // The posts actually commented on, each one once.
      Future<List<int>> posts({bool? distinct, SdbFilter? filter}) async {
        var records = await commentPostIndex.findJoinedRecords<int, SdbModel>(
          db,
          target: postStore.asJoinTarget,
          options: SdbFindOptions(filter: filter),
          joinOptions: SdbJoinFindOptions(distinct: distinct),
        );
        return records.map((record) => record.key).toList();
      }

      expect(await posts(distinct: true), [1, 2]);
      expect(await posts(distinct: true, filter: _matchAllFilter), [
        1,
        2,
      ], reason: 'dart path');
      // Without distinct, one per comment that has a post.
      expect(await posts(), [1, 1, 2]);
      expect(await posts(filter: _matchAllFilter), [
        1,
        1,
        2,
      ], reason: 'dart path');
    });

    test('index source, offset and limit', () async {
      await bothWays(
        ({filter}) => commentsWithPost(offset: 1, limit: 2, filter: filter),
        ['12->1', '13->2'],
      );
    });

    test('index source, descending', () async {
      // Two comments share a post id, and the order of such a tie when the
      // index is walked backwards is not specified: an index cursor sorts on
      // the index key alone, so memory keeps the tie ascending while sqflite
      // reverses it. Only the index key order is asserted here.
      for (var filter in [null, _matchAllFilter]) {
        var rows = await commentsWithPost(descending: true, filter: filter);
        var reason = filter == null ? 'native path' : 'dart path';
        expect(rows.length, 4, reason: reason);
        expect(rows[0], '15->null', reason: reason);
        expect(rows[1], '13->2', reason: reason);
        expect(rows.sublist(2)..sort(), ['11->1', '12->1'], reason: reason);
      }
    });

    test('index source, boundaries on the index key', () async {
      await bothWays(
        ({filter}) => commentsWithPost(
          boundaries: SdbBoundaries.values(1, 3),
          filter: filter,
        ),
        ['11->1', '12->1', '13->2'],
      );
    });

    test('index source, chunk by chunk', () async {
      expect(await commentsWithPost(chunkSize: 2), [
        '11->1',
        '12->1',
        '13->2',
        '15->null',
      ]);
    });

    test('index source joined on an index', () async {
      // Both sides through an index: every comment with the comments sharing
      // its post, itself included.
      var rows = <String>[];
      await commentPostIndex.joinIterate<int, SdbModel>(
        db,
        target: commentPostIndex.asJoinTarget,
        joinOptions: const SdbJoinFindOptions(inner: true),
        onRow: (row) {
          rows.add('${row.record.key}->${row.joinedRecord?.key}');
          return true;
        },
      );
      expect(rows, [
        '11->11',
        '11->12',
        '12->11',
        '12->12',
        '13->13',
        // Its post does not exist, but it shares that post id with itself.
        '15->15',
      ]);
    });

    test('joinCount', () async {
      expect(
        await postStore.joinCount<int, SdbModel>(
          db,
          target: commentPostIndex.asJoinTarget,
        ),
        4,
      );
      expect(
        await postStore.joinCount<int, SdbModel>(
          db,
          target: commentPostIndex.asJoinTarget,
          joinOptions: const SdbJoinFindOptions(inner: true),
        ),
        3,
      );
      expect(
        await commentPostIndex.joinCount<int, SdbModel>(
          db,
          target: postStore.asJoinTarget,
        ),
        4,
      );
      expect(
        await commentPostIndex.joinCount<int, SdbModel>(
          db,
          target: postStore.asJoinTarget,
          joinOptions: const SdbJoinFindOptions(inner: true),
        ),
        3,
      );
    });

    test('findJoinRows on an index', () async {
      var rows = await commentPostIndex.findJoinRows<int, SdbModel>(
        db,
        target: postStore.asJoinTarget,
        joinOptions: const SdbJoinFindOptions(inner: true),
      );
      expect(rows.map((row) => row.record.key).toList(), [11, 12, 13]);
      expect(rows.map((row) => row.joinedRecord!.key).toList(), [1, 1, 2]);
      expect(rows.map((row) => row.joinKey).toList(), [1, 1, 2]);
    });

    test('findJoinRecords on an index', () async {
      // The comments that do have a post, one entry each.
      var records = await commentPostIndex.findJoinRecords<int, SdbModel>(
        db,
        target: postStore.asJoinTarget,
        joinOptions: const SdbJoinFindOptions(inner: true),
      );
      expect(records.map((record) => record.key).toList(), [11, 12, 13]);
    });

    test('a target is a store or an index, never both nor none', () async {
      // Passing neither or both is a compile error now: the join takes one
      // required [SdbJoinTarget]. What is left to check is that both kinds
      // resolve to the right store and index.
      var storeTarget = postStore.asJoinTarget;
      expect(storeTarget.store, postStore);
      expect(storeTarget.index, isNull);

      var indexTarget = commentPostIndex.asJoinTarget;
      expect(indexTarget.store, commentStore);
      expect(indexTarget.index, commentPostIndex);
    });
  });

  group('sdb_join_nested', () {
    late SdbDatabase db;
    var dbName = 'sdb_join_nested.db';
    var parentStore = SdbStoreRef<String, SdbModel>('nested_parent');
    var childStore = SdbStoreRef<String, SdbModel>('nested_child');
    var indexedChildStore = SdbStoreRef<String, SdbModel>(
      'nested_indexed_child',
    );
    var childIndex = indexedChildStore.index<String>('parentId');

    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              parentStore.schema(),
              childStore.schema(),
              indexedChildStore.schema(
                indexes: [childIndex.schema(keyPath: 'ref.parentId')],
              ),
            ],
          ),
        ),
      );
      await db.inStoresTransaction(
        [parentStore, childStore, indexedChildStore],
        SdbTransactionMode.readWrite,
        (txn) async {
          await parentStore.record('a').put(txn, {'label': 'pa'});
          await parentStore.record('b').put(txn, {'label': 'pb'});
          for (var store in [childStore, indexedChildStore]) {
            await store.record('c1').put(txn, {
              'ref': {'parentId': 'a'},
            });
            await store.record('c2').put(txn, {
              'ref': {'parentId': 'b'},
            });
            // No nested map at all.
            await store.record('c3').put(txn, {'other': 1});
          }
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    for (var store in ['plain', 'indexed']) {
      test('nested key path, string keys ($store)', () async {
        var childStoreRef = store == 'indexed' ? indexedChildStore : childStore;
        var rows = <String>[];
        await childStoreRef.joinIterate<String, SdbModel>(
          db,
          target: parentStore.asJoinTarget,
          joinKeyPath: 'ref.parentId',
          onRow: (row) {
            rows.add('${row.record.key}->${row.joinedRecord?.key}');
            return true;
          },
        );
        expect(rows, ['c1->a', 'c2->b', 'c3->null']);
      });
    }
  });
}
