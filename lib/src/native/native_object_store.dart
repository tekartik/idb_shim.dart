part of idb_browser;

class _NativeObjectStore extends ObjectStore {
  idb.ObjectStore idbObjectStore;
  _NativeObjectStore(this.idbObjectStore);

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    return new _NativeIndex(idbObjectStore.createIndex(name, keyPath, unique: unique, multiEntry: multiEntry));
  }

  @override
  Future add(dynamic value, [dynamic key]) {
    return idbObjectStore.add(value, key);
  }

  @override
  Future getObject(dynamic key) {
    return idbObjectStore.getObject(key);
  }

  @override
  Future clear() {
    return idbObjectStore.clear();
  }

  @override
  Future put(dynamic value, [dynamic key]) {
    return idbObjectStore.put(value, key);
  }

  @override
  Future delete(key) {
    return idbObjectStore.delete(key);
  }

  @override
  Index index(String name) {
    return new _NativeIndex(idbObjectStore.index(name));
  }

  @override
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    _NativeCursorWithValueController ctlr = new _NativeCursorWithValueController(idbObjectStore.openCursor(key: key, range: _nativeKeyRange(range), direction: direction, autoAdvance: autoAdvance));

    return ctlr.stream;

  }

  @override
  Future<int> count([dynamic key_OR_range]) {
    return idbObjectStore.count(key_OR_range);
  }
}

