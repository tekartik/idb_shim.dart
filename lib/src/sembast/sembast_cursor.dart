part of idb_shim_sembast;

sdb.Filter _keyCursorFilter(String keyField, key, KeyRange range) {
  if (range != null) {
    return _keyRangeFilter(keyField, range);
  } else {
    return _keyFilter(keyField, key);
  }
}

sdb.Filter _keyRangeFilter(String keyPath, KeyRange range) {
  sdb.Filter lowerFilter;
  sdb.Filter upperFilter;
  List<sdb.Filter> filters = [];
  if (range.lower != null) {
    if (range.lowerOpen == true) {
      lowerFilter = new sdb.Filter.greaterThan(keyPath, range.lower);
    } else {
      lowerFilter = new sdb.Filter.greaterThanOrEquals(keyPath, range.lower);
    }
    filters.add(lowerFilter);
  }
  if (range.upper != null) {
    if (range.upperOpen == true) {
      upperFilter = new sdb.Filter.lessThan(keyPath, range.upper);
    } else {
      upperFilter = new sdb.Filter.lessThanOrEquals(keyPath, range.upper);
    }
    filters.add(upperFilter);
  }
  return new sdb.Filter.and(filters);
}

sdb.Filter _keyFilter(String keyPath, var key) {
  if (key == null) {
    // key must not be nulled
    return new sdb.Filter.notEqual(keyPath, null);
  }
  return new sdb.Filter.equal(keyPath, key);
}

sdb.Filter _keyOrRangeFilter(String keyPath, [key_OR_range]) {
  if (key_OR_range is KeyRange) {
    return _keyRangeFilter(keyPath, key_OR_range);
  } else {
    return _keyFilter(keyPath, key_OR_range);
  }
}

//abstract class IdbCursor {
//  //
//  // Idb redefinition
//  //
//  String get direction;
//  void advance(int count);
//  Future delete();
//  void next();
//  Object get primaryKey;
//  Object get key;
//  Future update(value);
//  //Object get value;
//}

abstract class _SdbKeyCursorMixin implements Cursor {
  // set upon creation
  int recordIndex;
  _SdbBaseCursorControllerMixin ctlr;

  _SdbObjectStore get store => ctlr.store;
  IdbCursorMeta get meta => ctlr.meta;

  sdb.Record get record => ctlr.records[recordIndex];
  //
  // Idb
  //
  @override
  String get direction => meta.direction;
  void advance(int count) {
    // no future
    ctlr.advance(count);
  }

  @override
  void next() => advance(1);

  @override
  Future delete() {
    return store.delete(record.key);
  }

  @override
  Object get key => record.key;

  @override
  Object get primaryKey => record.key;

  @override
  Future update(value) => store.put(value, primaryKey);
}

abstract class _SdbIndexCursorMixin implements Cursor {
  _SdbIndexCursorControllerMixin get indexCtlr;
  _SdbIndex get index => indexCtlr.index;
  sdb.Record get record;

  ///
  /// Return the index key of the record
  ///
  @override
  Object get key => record.value[index.keyPath];
}

abstract class _SdbCursorWithValueMixin implements CursorWithValue {
  sdb.Record get record;

  @override
  Object get value => record.value;
}

class _SdbIndexKeyCursor extends Object
    with _SdbKeyCursorMixin, _SdbIndexCursorMixin
    implements Cursor {
  _SdbIndexKeyCursorController get indexCtlr => ctlr;

  _SdbIndexKeyCursor(_SdbIndexKeyCursorController ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }

  ///
  /// Return the index key of the record
  ///
  @override
  Object get key => record.value[indexCtlr.index.keyPath];
}

/*
class _SdbStoreKeyCursor extends Object
    with _SdbKeyCursorMixin
    implements Cursor {
  _SdbStoreKeyCursor(_SdbBaseCursorControllerMixin ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }
}
*/

class _SdbIndexCursorWithValue extends Object
    with _SdbKeyCursorMixin, _SdbCursorWithValueMixin {
  _SdbIndexCursorWithValueController get indexCtlr => ctlr;
  _SdbIndexCursorWithValue(_SdbBaseCursorControllerMixin ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }

  ///
  /// Return the index key of the record
  ///
  @override
  Object get key => record.value[indexCtlr.index.keyPath];
}

class _SdbStoreCursorWithValue extends Object
    with _SdbKeyCursorMixin, _SdbCursorWithValueMixin {
  _SdbStoreCursorWithValue(_SdbBaseCursorControllerMixin ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }
}

/*
class _SdbCursorWithValue extends Object
    with _SdbKeyCursorMixin, _SdbCursorWithValueMixin {
  _SdbCursorWithValue(_SdbBaseCursorControllerMixin ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }
}
*/

abstract class _ISdbCursor {
  sdb.Filter get filter;
  sdb.SortOrder get sortOrder;
}

abstract class _SdbIndexCursorControllerMixin implements _ISdbCursor {
  _SdbIndex index;
  IdbCursorMeta get meta;

  @override
  sdb.SortOrder get sortOrder {
    return index.sortOrder(meta.ascending);
  }

  @override
  sdb.Filter get filter {
    return index.cursorFilter(meta.key, meta.range);
  }
}

abstract class _SdbStoreCursorControllerMixin implements _ISdbCursor {
  _SdbObjectStore get store;
  IdbCursorMeta get meta;

  @override
  sdb.SortOrder get sortOrder {
    return store.sortOrder(meta.ascending);
  }

  @override
  sdb.Filter get filter {
    return store.cursorFilter(meta.key, meta.range);
  }
}

abstract class _SdbBaseCursorControllerMixin implements _ISdbCursor {
  IdbCursorMeta meta;
  _SdbObjectStore get store;

// To implement for KeyCursor vs CursorWithValue
  Cursor nextEvent(int index);

  List<sdb.Record> records;
  bool get done => currentIndex == null;
  int currentIndex = -1;
  StreamController ctlr;

  void init() {
    ctlr = new StreamController(sync: true);
  }

  Future autoNext() {
    return advance(1).then((_) {
      if (meta.autoAdvance && (!done)) {
        return autoNext();
      }
    });
  }

  Future advance(int count) {
    currentIndex += count;
    if (currentIndex >= records.length) {
      currentIndex = null;
      return ctlr.close();
    }

    ctlr.add(nextEvent(currentIndex));
    return new Future.value();
  }

  Future openCursor() {
    sdb.Filter filter = this.filter;
    sdb.SortOrder sortOrder = this.sortOrder;
    sdb.Finder finder = new sdb.Finder(filter: filter, sortOrders: [sortOrder]);
    return store.sdbStore.findRecords(finder).then((List<sdb.Record> records) {
      this.records = records;
      return autoNext();
    });
  }
}

abstract class _SdbKeyCursorControllerMixin {
  StreamController<Cursor> get ctlr;
  Stream<Cursor> get stream => ctlr.stream;
}

abstract class _SdbCursorWithValueControllerMixin {
  StreamController<CursorWithValue> get ctlr;
  Stream<CursorWithValue> get stream => ctlr.stream;
}

/*
class _SdbStoreKeyCursorController extends Object
    with
        _SdbKeyCursorControllerMixin,
        _SdbBaseCursorControllerMixin,
        _SdbStoreCursorControllerMixin {
  _SdbObjectStore store;
  _SdbStoreKeyCursorController(this.store, IdbCursorMeta meta) {
    this.meta = meta;
    init();
  }

  Cursor nextEvent(int index) {
    _SdbStoreKeyCursor cursor = new _SdbStoreKeyCursor(this, index);
    return cursor;
  }
}
*/

class _SdbIndexKeyCursorController extends Object
    with
        _SdbKeyCursorControllerMixin,
        _SdbBaseCursorControllerMixin,
        _SdbIndexCursorControllerMixin {
  _SdbIndex index;
  _SdbObjectStore get store => index.store;
  _SdbIndexKeyCursorController(_SdbIndex index, IdbCursorMeta meta) {
    this.meta = meta;
    this.index = index;
    init();
  }

  Cursor nextEvent(int index) {
    _SdbIndexKeyCursor cursor = new _SdbIndexKeyCursor(this, index);
    return cursor;
  }
}

class _SdbIndexCursorWithValueController extends Object
    with
        _SdbCursorWithValueControllerMixin,
        _SdbBaseCursorControllerMixin,
        _SdbIndexCursorControllerMixin {
  _SdbIndex index;
  _SdbObjectStore get store => index.store;
  _SdbIndexCursorWithValueController(this.index, IdbCursorMeta meta) {
    this.meta = meta;
    init();
  }

  Cursor nextEvent(int index) {
    _SdbIndexCursorWithValue cursor = new _SdbIndexCursorWithValue(this, index);
    return cursor;
  }
}

class _SdbStoreCursorWithValueController extends Object
    with
        _SdbCursorWithValueControllerMixin,
        _SdbBaseCursorControllerMixin,
        _SdbStoreCursorControllerMixin {
  _SdbObjectStore store;
  _SdbStoreCursorWithValueController(this.store, IdbCursorMeta meta) {
    this.meta = meta;
    init();
  }

  Cursor nextEvent(int index) {
    _SdbStoreCursorWithValue cursor = new _SdbStoreCursorWithValue(this, index);
    return cursor;
  }
}
