import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_validation.dart';
import 'package:idb_shim/src/sembast/sembast_cursor.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sdb;

class IndexSembast extends Index with IndexWithMetaMixin {
  final ObjectStoreSembast store;
  final IdbIndexMeta meta;

  IndexSembast(this.store, this.meta);

  Future<T> inTransaction<T>(FutureOr<T> computation()) {
    return store.inTransaction(computation);
  }

  _indexKeyOrRangeFilter([key_OR_range]) {
    // null means all entry without null value
    if (key_OR_range == null) {
      return new sdb.Filter.notEqual(meta.keyPath, null);
    }
    return keyOrRangeFilter(meta.keyPath, key_OR_range);
  }

  @override
  Future<int> count([key_OR_range]) {
    return inTransaction(() {
      return store.sdbStore.count(_indexKeyOrRangeFilter(key_OR_range));
    });
  }

  @override
  Future get(key) {
    checkKeyParam(key);
    return inTransaction(() {
      sdb.Finder finder =
          new sdb.Finder(filter: _indexKeyOrRangeFilter(key), limit: 1);
      return store.sdbStore
          .findRecords(finder)
          .then((List<sdb.Record> records) {
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
          new sdb.Finder(filter: _indexKeyOrRangeFilter(key), limit: 1);
      return store.sdbStore
          .findRecords(finder)
          .then((List<sdb.Record> records) {
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
        new IdbCursorMeta(key, range, direction, autoAdvance);
    IndexCursorWithValueControllerSembast ctlr =
        new IndexCursorWithValueControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Stream<Cursor> openKeyCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    IdbCursorMeta cursorMeta =
        new IdbCursorMeta(key, range, direction, autoAdvance);
    IndexKeyCursorControllerSembast ctlr =
        new IndexKeyCursorControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  sdb.Filter cursorFilter(key, KeyRange range) {
    return keyCursorFilter(keyPath, key, range);
  }

  sdb.SortOrder sortOrder(bool ascending) {
    return new sdb.SortOrder(keyPath, ascending);
  }
}
