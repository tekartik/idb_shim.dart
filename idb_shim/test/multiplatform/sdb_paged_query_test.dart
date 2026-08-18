// ignore_for_file: implementation_imports
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_paged_query.dart';
import 'package:idb_shim/src/sdb/sdb_paged_iterate.dart';
import 'package:idb_shim/utils/idb_cursor_utils.dart';
import 'package:test/test.dart';

/// In memory [IdbPagedQuerySupport], counting its queries: what the sdb layer
/// expects from an implementation able to page natively.
class _FakePaged implements IdbPagedQuerySupport {
  _FakePaged(int count)
    : rows = List.generate(count, (i) => (key: i, value: 'value $i'));

  final List<({int key, String value})> rows;

  /// (offset, limit) of every query run.
  final queries = <(int?, int?)>[];

  /// Updates applied through [pagedRowUpdate].
  final updates = <int, Object>{};

  List<({int key, String value})> _page(
    String? direction,
    int? offset,
    int? limit,
  ) {
    var list = direction == idbDirectionPrev
        ? rows.reversed.toList()
        : List.of(rows);
    var result = list.skip(offset ?? 0);
    if (limit != null && limit >= 0) {
      result = result.take(limit);
    }
    return result.toList();
  }

  @override
  Future<List<IdbCursorRow>> pagedRowList({
    KeyRange? range,
    String? direction,
    int? offset,
    int? limit,
  }) async {
    queries.add((offset, limit));
    return _page(
      direction,
      offset,
      limit,
    ).map((e) => IdbPagedCursorRow(e.key, e.key, e.value)).toList();
  }

  @override
  Future<List<IdbKeyCursorRow>> pagedKeyRowList({
    KeyRange? range,
    String? direction,
    int? offset,
    int? limit,
  }) async {
    queries.add((offset, limit));
    return _page(
      direction,
      offset,
      limit,
    ).map((e) => IdbKeyCursorRow(e.key, e.key)).toList();
  }

  @override
  Future<void> pagedRowUpdate(Object primaryKey, Object value) async {
    updates[primaryKey as int] = value;
  }
}

void main() {
  group('common_paged_query', () {
    test('idbPagedQuerySupportOrNull', () {
      var paged = _FakePaged(0);
      expect(idbPagedQuerySupportOrNull(paged), paged);
      expect(idbPagedQuerySupportOrNull(null), isNull);
      expect(idbPagedQuerySupportOrNull('not a store'), isNull);
      expect(idbPagedQuerySupportOrNull(Object()), isNull);
    });

    test('IdbPagedCursorRow', () {
      var row = IdbPagedCursorRow('key', 'primaryKey', 'value');
      expect(row.key, 'key');
      expect(row.primaryKey, 'primaryKey');
      expect(row.value, 'value');
      expect(row, isA<IdbCursorRow>());
    });
  });

  group('sdb_paged_iterate', () {
    Future<List<Object>> streamKeys(
      _FakePaged paged, {
      int? offset,
      int? limit,
      String? direction,
      int chunkSize = 10,
    }) => sdbPagedRowStream(
      paged: paged,
      offset: offset,
      limit: limit,
      direction: direction,
      chunkSize: chunkSize,
    ).map((row) => row.key).toList();

    test('reads every row, chunk by chunk', () async {
      var paged = _FakePaged(25);
      expect(await streamKeys(paged), List.generate(25, (i) => i));
      // 10 + 10 + 5, the short chunk ends it.
      expect(paged.queries, [(0, 10), (10, 10), (20, 10)]);
    });

    test('a full last chunk needs one more query', () async {
      var paged = _FakePaged(20);
      expect(await streamKeys(paged), List.generate(20, (i) => i));
      // The last chunk is full, one more query is needed to see the end.
      expect(paged.queries, [(0, 10), (10, 10), (20, 10)]);
    });

    test('empty', () async {
      var paged = _FakePaged(0);
      expect(await streamKeys(paged), isEmpty);
      expect(paged.queries, [(0, 10)]);
    });

    test('offset and limit', () async {
      var paged = _FakePaged(25);
      expect(await streamKeys(paged, offset: 5, limit: 7), [
        5,
        6,
        7,
        8,
        9,
        10,
        11,
      ]);
      // The limit is smaller than the chunk, a single query.
      expect(paged.queries, [(5, 7)]);

      paged = _FakePaged(25);
      expect(
        await streamKeys(paged, offset: 3, limit: 15),
        List.generate(15, (i) => i + 3),
      );
      expect(paged.queries, [(3, 10), (13, 5)]);

      paged = _FakePaged(25);
      expect(await streamKeys(paged, offset: 20, limit: 10), [
        20,
        21,
        22,
        23,
        24,
      ]);
      expect(await streamKeys(paged, offset: 25, limit: 10), isEmpty);
      expect(await streamKeys(paged, limit: 0), isEmpty);
    });

    test('descending', () async {
      var paged = _FakePaged(25);
      expect(await streamKeys(paged, direction: idbDirectionPrev, limit: 3), [
        24,
        23,
        22,
      ]);
    });

    test('is lazy, a consumer stopping early stops the queries', () async {
      var paged = _FakePaged(100);
      var keys = <Object>[];
      await for (var row in sdbPagedRowStream(paged: paged, chunkSize: 10)) {
        keys.add(row.key);
        if (keys.length == 12) {
          break;
        }
      }
      expect(keys.length, 12);
      // Only the two chunks holding those rows were read.
      expect(paged.queries, [(0, 10), (10, 10)]);
    });

    test('iterate visits every row', () async {
      var paged = _FakePaged(25);
      var keys = <Object>[];
      await sdbPagedIterate(
        paged: paged,
        chunkSize: 10,
        handleRow: (row) {
          keys.add(row.key);
          return true;
        },
      );
      expect(keys, List.generate(25, (i) => i));
    });

    test('iterate stops when the handler returns false', () async {
      var paged = _FakePaged(100);
      var keys = <Object>[];
      await sdbPagedIterate(
        paged: paged,
        chunkSize: 10,
        handleRow: (row) {
          keys.add(row.key);
          return keys.length < 12;
        },
      );
      expect(keys.length, 12);
      expect(paged.queries, [(0, 10), (10, 10)]);
    });

    test('iterate awaits an async handler', () async {
      var paged = _FakePaged(15);
      var keys = <Object>[];
      await sdbPagedIterate(
        paged: paged,
        chunkSize: 10,
        handleRow: (row) async {
          await Future<void>.delayed(Duration.zero);
          keys.add(row.key);
          return true;
        },
      );
      expect(keys, List.generate(15, (i) => i));
    });

    test('delete keeps the offset put between chunks', () async {
      var paged = _FakePaged(25);
      var deleted = <Object>[];
      await sdbPagedDelete(
        paged: paged,
        chunkSize: 10,
        deleteKey: (primaryKey) async {
          deleted.add(primaryKey);
          paged.rows.removeWhere((e) => e.key == primaryKey);
        },
      );
      expect(deleted, List.generate(25, (i) => i));
      expect(paged.rows, isEmpty);
      // Always the same offset, the rows left move up as they are deleted.
      expect(paged.queries, [(null, 10), (null, 10), (null, 10)]);
    });

    test('delete honours offset and limit', () async {
      var paged = _FakePaged(25);
      var deleted = <Object>[];
      await sdbPagedDelete(
        paged: paged,
        chunkSize: 10,
        offset: 5,
        limit: 12,
        deleteKey: (primaryKey) async {
          deleted.add(primaryKey);
          paged.rows.removeWhere((e) => e.key == primaryKey);
        },
      );
      expect(deleted, List.generate(12, (i) => i + 5));
      expect(paged.rows.map((e) => e.key), [
        0,
        1,
        2,
        3,
        4,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
      ]);
      expect(paged.queries, [(5, 10), (5, 2)]);
    });
  });
}
