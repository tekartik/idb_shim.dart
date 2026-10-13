// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_validation.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sembast/sembast_cursor.dart';
import 'package:idb_shim/src/sembast/sembast_filter.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sembast;

/// IndexSembast representation.
class IndexSembast extends Index with IndexWithMetaMixin {
  IndexSembast(this.store, this.meta);
  final ObjectStoreSembast store;
  @override
  final IdbIndexMeta meta;

  Future<T> inTransaction<T>(FutureOr<T> Function() computation) {
    return store.inTransaction(computation);
  }

  sembast.Filter _indexKeyOrRangeFilter([Object? keyOrRange]) {
    // null means all entry without null value
    if (keyOrRange == null) {
      return keyNotNullFilter(meta.keyPath);
    }
    return keyOrRangeFilter(meta.keyPath, keyOrRange, multiEntry);
  }

  /// The entries of the index matching [keyOrRange] (any key when null): one
  /// per record, one per distinct array item for a multiEntry index, sorted
  /// like IndexedDB by key then by primary key, in reverse if not
  /// [ascending].
  Future<List<IndexRecordSnapshotSembast>> txnEntries(
    Object? keyOrRange, {
    bool ascending = true,
  }) async {
    var records = await store.sembastStore.find(
      store.sembastClient,
      finder: sembast.Finder(filter: _indexKeyOrRangeFilter(keyOrRange)),
    );
    var entries = <IndexRecordSnapshotSembast>[];
    for (var record in records) {
      for (var key in recordKeyPathKeys(record, keyPath, multiEntry)) {
        if (keyMatchesKeyOrRange(key, keyOrRange)) {
          // The key is kept as stored (like the record values).
          entries.add(IndexRecordSnapshotSembast(store, key, record));
        }
      }
    }
    entries.sort((a, b) {
      var cmp = compareKeys(a.key, b.key);
      if (cmp == 0) {
        cmp = compareKeys(a.primaryKey, b.primaryKey);
      }
      return ascending ? cmp : -cmp;
    });
    return entries;
  }

  /// The entries matching [keyOrRange], at most [count].
  Future<Iterable<IndexRecordSnapshotSembast>> _txnEntries(
    Object? keyOrRange, [
    int? count,
  ]) async {
    var entries = await txnEntries(keyOrRange);
    count = idbGetAllCountOrNull(count);
    return count == null ? entries : entries.take(count);
  }

  void _checkKeyOrRangeParam(Object key) {
    if (key is! KeyRange) {
      checkKeyParam(key);
    }
  }

  @override
  Future<int> count([keyOrRange]) {
    return inTransaction(() async {
      return (await txnEntries(keyOrRange)).length;
    });
  }

  @override
  Future get(Object key) {
    _checkKeyOrRangeParam(key);
    return inTransaction(() async {
      var entries = await _txnEntries(key, 1);
      return entries.isEmpty
          ? null
          : store.recordToValue(entries.first.snapshot);
    });
  }

  @override
  Future getKey(Object key) {
    _checkKeyOrRangeParam(key);
    return inTransaction(() async {
      var entries = await _txnEntries(key, 1);
      return entries.isEmpty ? null : entries.first.primaryKey;
    });
  }

  @override
  Stream<CursorWithValue> openCursor({
    key,
    KeyRange? range,
    String? direction,
    bool? autoAdvance,
  }) {
    final cursorMeta = IdbCursorMeta(key, range, direction, autoAdvance);
    final ctlr = IndexCursorWithValueControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Stream<Cursor> openKeyCursor({
    key,
    KeyRange? range,
    String? direction,
    bool? autoAdvance,
  }) {
    final cursorMeta = IdbCursorMeta(key, range, direction, autoAdvance);
    final ctlr = IndexKeyCursorControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  sembast.Filter cursorFilter(Object? key, KeyRange? range) {
    return keyCursorFilter(keyPath, key, range, multiEntry);
  }

  List<sembast.SortOrder> sortOrders(bool ascending) =>
      keyPathSortOrders(keyPath, ascending);

  @override
  Future<List<Object>> getAll([query, int? count]) {
    return inTransaction(() async {
      return (await _txnEntries(query, count))
          .map((entry) => store.recordToValue(entry.snapshot)!)
          .toList(growable: false);
    });
  }

  @override
  Future<List<Object>> getAllKeys([query, int? count]) {
    return inTransaction(() async {
      return (await _txnEntries(
        query,
        count,
      )).map((entry) => entry.primaryKey).toList(growable: false);
    });
  }
}
