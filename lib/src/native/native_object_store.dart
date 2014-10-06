part of idb_native;

class _NativeObjectStore extends ObjectStore {
  idb.ObjectStore idbObjectStore;
  _NativeObjectStore(this.idbObjectStore);

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    return new _NativeIndex(idbObjectStore.createIndex(name, keyPath, unique: unique, multiEntry: multiEntry));
  }

  @override
  Future add(dynamic value, [dynamic key]) {
    return idbObjectStore.add(value, key).catchError((e) {
      throw new _NativeDatabaseError(e);
    });
  }

  @override
  Future getObject(dynamic key) {
    return idbObjectStore.getObject(key);
  }

  @override
  Future clear() {
    return idbObjectStore.clear().catchError((e) {
      throw new DatabaseError(e.toString());
    });
  }

  @override
  Future put(dynamic value, [dynamic key]) {
    return idbObjectStore.put(value, key).catchError((e) {
      throw new DatabaseError(e.toString());
    });
  }

  @override
  Future delete(key) {
    return idbObjectStore.delete(key).catchError((e) {
      throw new DatabaseError(e.toString());
    });
  }

  @override
  Index index(String name) {
    return new _NativeIndex(idbObjectStore.index(name));
  }

  @override
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    idb.KeyRange idbKeyRange = _nativeKeyRange(range);
    //idbDevWarning;
    //idbDevPrint("kr1 $range native $idbKeyRange");

    Stream<idb.CursorWithValue> stream;

    // IE workaround!!!
    if (idbKeyRange == null) {
      stream = idbObjectStore.openCursor( //
      key: key, //
      // Weird on ie, uncommenting this line
      // although null makes it crash
      // range: idbKeyRange
      direction: direction, //
      autoAdvance: autoAdvance);
    } else {
      stream = idbObjectStore.openCursor( //
      key: key, //
      range: idbKeyRange, direction: direction, //
      autoAdvance: autoAdvance);
    }

    _NativeCursorWithValueController ctlr = new _NativeCursorWithValueController(//
    stream);
    //idbDevPrint("kr2 $range native $idbKeyRange");
    return ctlr.stream;

  }

  @override
  Future<int> count([dynamic key_OR_range]) {
    Future<int> countFuture;
    if (key_OR_range == null) {
      countFuture = idbObjectStore.count();
    } else if (key_OR_range is KeyRange) {
      idb.KeyRange idbKeyRange = _nativeKeyRange(key_OR_range);
      countFuture = idbObjectStore.count(idbKeyRange);
    } else {
      countFuture = idbObjectStore.count(key_OR_range);
    }
    return countFuture;
  }

  @override
  get keyPath => idbObjectStore.keyPath;

  @override
  get autoIncrement => idbObjectStore.autoIncrement;

  @override
  get name => idbObjectStore.name;
  
  @override
  List<String> get indexNames => idbObjectStore.indexNames;
}
