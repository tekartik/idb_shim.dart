part of idb_shim_sembast;

class _SdbIndex extends Index with IndexWithMetaMixin {
  final _SdbObjectStore store;
  final IdbIndexMeta meta;

  _SdbIndex(this.store, this.meta);

  Future inTransaction(Future computation()) {
    return store.inTransaction(computation);
  }

  _indexKeyOrRangeFilter([key_OR_range]) {
    // null means all entry without null value
    if (key_OR_range == null) {
      return new sdb.Filter.notEqual(meta.keyPath, null);
    }
    return _keyOrRangeFilter(meta.keyPath, key_OR_range);
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
    _SdbIndexCursorWithValueController ctlr =
        new _SdbIndexCursorWithValueController(this, cursorMeta);

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
    _SdbIndexKeyCursorController ctlr =
        new _SdbIndexKeyCursorController(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  sdb.Filter cursorFilter(key, KeyRange range) {
    return _keyCursorFilter(keyPath, key, range);
  }

  sdb.SortOrder sortOrder(bool ascending) {
    return new sdb.SortOrder(keyPath, ascending);
  }
}
