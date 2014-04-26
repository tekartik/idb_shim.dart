part of idb_browser;

class _NativeIndex extends Index {
  idb.Index idbIndex;
  _NativeIndex(this.idbIndex);

  @override
  Future get(dynamic key) {
    return idbIndex.get(key);
  }

  @override
  Future<int> count([key_OR_range]) {
    return idbIndex.count(key_OR_range);
  }

  @override
  Stream<Cursor> openKeyCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    _NativeCursorController ctlr = new _NativeCursorController(idbIndex.openKeyCursor(key: key, range: range == null ? null : _nativeKeyRange(range), direction: direction, autoAdvance: autoAdvance));
    return ctlr.stream;
  }

  /**
   * Same implementation than for the Store
   */
  @override
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    _NativeCursorWithValueController ctlr = new _NativeCursorWithValueController(idbIndex.openCursor(key: key, range: range == null ? null : _nativeKeyRange(range), direction: direction, autoAdvance: autoAdvance));

    return ctlr.stream;
  }
}

