part of idb_shim_native;

class _NativeObjectStore extends ObjectStore {
  idb.ObjectStore idbObjectStore;
  _NativeObjectStore(this.idbObjectStore);

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    return new _NativeIndex(idbObjectStore.createIndex(name, keyPath,
        unique: unique, multiEntry: multiEntry));
  }

  @override
  void deleteIndex(String name) {
    _catchNativeError(() {
      idbObjectStore.deleteIndex(name);
    });
  }

  @override
  Future add(dynamic value, [dynamic key]) {
    return _catchAsyncNativeError(() {
      return idbObjectStore.add(value, key);
    });
  }

  // Not async please for ie!
  @override
  Future getObject(dynamic key) {
    return _catchAsyncNativeError(() {
      return idbObjectStore.getObject(key);
    });
  }

  @override
  Future clear() {
    return _catchAsyncNativeError(() {
      return idbObjectStore.clear();
    });
  }

  @override
  Future put(dynamic value, [dynamic key]) {
    return _catchAsyncNativeError(() {
      return idbObjectStore.put(value, key);
    });
  }

  @override
  Future delete(key) {
    return _catchAsyncNativeError(() {
      return idbObjectStore.delete(key);
    });
  }

  @override
  Index index(String name) {
    return new _NativeIndex(idbObjectStore.index(name));
  }

  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    idb.KeyRange idbKeyRange = _nativeKeyRange(range);
    //idbDevWarning;
    //idbDevPrint("kr1 $range native $idbKeyRange");

    Stream<idb.CursorWithValue> stream;

    // IE workaround!!!
    if (idbKeyRange == null) {
      stream = idbObjectStore.openCursor(
          //
          key: key, //
          // Weird on ie, uncommenting this line
          // although null makes it crash
          // range: idbKeyRange
          direction: direction, //
          autoAdvance: autoAdvance);
    } else {
      stream = idbObjectStore.openCursor(
          //
          key: key, //
          range: idbKeyRange,
          direction: direction, //
          autoAdvance: autoAdvance);
    }

    _NativeCursorWithValueController ctlr =
        new _NativeCursorWithValueController(//
            stream);
    //idbDevPrint("kr2 $range native $idbKeyRange");
    return ctlr.stream;
  }

  //@override
  // Used for iterating through an object store with a key cursor.
  /*
  Stream<Cursor> openKeyCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    idb.KeyRange idbKeyRange = _nativeKeyRange(range);
    //idbDevWarning;
    //idbDevPrint("kr1 $range native $idbKeyRange");

    Stream<idb.Cursor> stream;

      stream = idbObjectStore.openKeyCursor(
      //
          key: key, //
          range: idbKeyRange,
          direction: direction, //
          autoAdvance: autoAdvance);


    _NativeCursorWithValueController ctlr =
    new _NativeCursorWithValueController(//
        stream);
    //idbDevPrint("kr2 $range native $idbKeyRange");
    return ctlr.stream;
  }
  */

  @override
  Future<int> count([dynamic key_OR_range]) {
    return _catchAsyncNativeError(() {
      Future<int> countFuture;
      if (key_OR_range == null) {
        countFuture = idbObjectStore.count();

        /*  .catchError((e) {
          // as of SDK 1.12 count() without argument crashes
          // so let's count manually
          if (e.toString().contains('DataError')) {
            int count = 0;
            // count manually
            return idbObjectStore.openCursor(autoAdvance: true).listen((_) {
              count++;
            }).asFuture(count);
          } else {
            throw e;
          }
          });
          */
      } else if (key_OR_range is KeyRange) {
        idb.KeyRange idbKeyRange = _nativeKeyRange(key_OR_range);
        countFuture = idbObjectStore.count(idbKeyRange);
      } else {
        countFuture = idbObjectStore.count(key_OR_range);
      }
      return countFuture;
    });
  }

  @override
  String get keyPath => idbObjectStore.keyPath as String;

  // ie return null so make sure it is a bool
  @override
  bool get autoIncrement => idbObjectStore.autoIncrement;

  @override
  String get name => idbObjectStore.name;

  @override
  List<String> get indexNames => idbObjectStore.indexNames;
}
