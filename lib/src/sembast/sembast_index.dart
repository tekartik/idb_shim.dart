import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_validation.dart';
import 'package:idb_shim/src/sembast/sembast_cursor.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sdb;

class IndexSembast extends Index with IndexWithMetaMixin {
  final ObjectStoreSembast store;
  @override
  final IdbIndexMeta meta;

  IndexSembast(this.store, this.meta);

  Future<T> inTransaction<T>(FutureOr<T> computation()) {
    return store.inTransaction(computation);
  }

  sdb.Filter _indexKeyOrRangeFilter([keyOrRange]) {
    // null means all entry without null value
    if (keyOrRange == null) {
      if (meta.keyPath is String) {
        return sdb.Filter.notEqual(meta.keyPath as String, null);
      } else {
        throw 'key_OR_range is null, keyPath must not be an array';
      }
    }
    return keyOrRangeFilter(meta.keyPath, keyOrRange);
  }

  @override
  Future<int> count([keyOrRange]) {
    return inTransaction(() {
      return store.sdbStore
          .count(store.sdbClient, filter: _indexKeyOrRangeFilter(keyOrRange));
    });
  }

  @override
  Future get(key) {
    checkKeyParam(key);
    return inTransaction(() {
      sdb.Finder finder =
          sdb.Finder(filter: _indexKeyOrRangeFilter(key), limit: 1);
      return store.sdbStore
          .find(store.sdbClient, finder: finder)
          .then((records) {
        if (records.isNotEmpty) {
          return records.first.value;
        }
      });
    });
  }

  @override
  Future getKey(key) {
    checkKeyParam(key);
    return inTransaction(() {
      sdb.Finder finder =
          sdb.Finder(filter: _indexKeyOrRangeFilter(key), limit: 1);
      return store.sdbStore
          .find(store.sdbClient, finder: finder)
          .then((records) {
        if (records.isNotEmpty) {
          return records.first.key;
        }
      });
    });
  }

  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    IdbCursorMeta cursorMeta =
        IdbCursorMeta(key, range, direction, autoAdvance);
    IndexCursorWithValueControllerSembast ctlr =
        IndexCursorWithValueControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Stream<Cursor> openKeyCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    IdbCursorMeta cursorMeta =
        IdbCursorMeta(key, range, direction, autoAdvance);
    IndexKeyCursorControllerSembast ctlr =
        IndexKeyCursorControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  sdb.Filter cursorFilter(key, KeyRange range) {
    return keyCursorFilter(keyPath, key, range);
  }

  List<sdb.SortOrder> sortOrders(bool ascending) =>
      keyPathSortOrders(keyPath, ascending);
}
