// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_validation.dart';
import 'package:idb_shim/src/sembast/sembast_cursor.dart';
import 'package:idb_shim/src/sembast/sembast_filter.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sembast;

class IndexSembast extends Index with IndexWithMetaMixin {
  final ObjectStoreSembast store;
  @override
  final IdbIndexMeta meta;

  IndexSembast(this.store, this.meta);

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

  @override
  Future<int> count([keyOrRange]) {
    return inTransaction(() {
      return store.sembastStore.count(
        store.sembastClient,
        filter: _indexKeyOrRangeFilter(keyOrRange),
      );
    });
  }

  @override
  Future get(key) {
    checkKeyParam(key);
    return inTransaction(() {
      final finder = sembast.Finder(
        filter: _indexKeyOrRangeFilter(key),
        limit: 1,
      );
      return store.sembastStore.find(store.sembastClient, finder: finder).then((
        records,
      ) {
        if (records.isNotEmpty) {
          return store.recordToValue(records.first);
        }
      });
    });
  }

  @override
  Future getKey(key) {
    checkKeyParam(key);
    return inTransaction(() {
      final finder = sembast.Finder(
        filter: _indexKeyOrRangeFilter(key),
        limit: 1,
      );
      return store.sembastStore.find(store.sembastClient, finder: finder).then((
        records,
      ) {
        if (records.isNotEmpty) {
          return records.first.key;
        }
      });
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
      final finder = sembast.Finder(
        filter: _indexKeyOrRangeFilter(query),
        limit: count,
        sortOrders: sortOrders(true),
      );
      return (await store.sembastStore.find(
        store.sembastClient,
        finder: finder,
      )).map((r) => store.recordToValue(r)!).toList(growable: false);
    });
  }

  @override
  Future<List<Object>> getAllKeys([query, int? count]) {
    return inTransaction(() async {
      final finder = sembast.Finder(
        filter: _indexKeyOrRangeFilter(query),
        limit: count,
        sortOrders: sortOrders(true),
      );
      return store.sembastStore.findKeys(store.sembastClient, finder: finder);
    });
  }
}
