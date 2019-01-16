import 'package:collection/collection.dart';
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sembast/sembast_index.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sdb;
import 'package:sembast/utils/value_utils.dart' as utils;

sdb.Filter keyCursorFilter(dynamic keyPath, key, KeyRange range) {
  if (range != null) {
    return keyRangeFilter(keyPath, range);
  } else
  // if (key != null)
  {
    return keyFilter(keyPath, key);
  }
  // no filtering
  // return null;
}

class KeyArrayRangeFilter implements sdb.Filter {
  final List keyList;
  final KeyRange range;

  KeyArrayRangeFilter(this.keyList, this.range);

  @override
  bool match(sdb.Record record) {
    List values =
        List.generate(keyList.length, (i) => record[keyList[i] as String]);

    // no null accepted
    for (var value in values) {
      if (value == null) {
        return false;
      }
    }

    if (range.lower != null) {
      List boundValues = range.lower as List;
      bool equals = true;
      for (int i = 0; i < keyList.length; i++) {
        var boundValue = boundValues[i];
        if (boundValue == null) {
          continue;
        }
        var value = values[i];
        if (utils.greaterThan(value, boundValue)) {
          return true;
        } else if (value == boundValue) {
          continue;
        } else {
          return false;
        }
      }

      if (range.lowerOpen == true && equals) {
        return false;
      }
    }
    if (range.upper != null) {
      List boundValues = range.upper as List;
      bool equals = true;
      for (int i = 0; i < keyList.length; i++) {
        var boundValue = boundValues[i];
        if (boundValue == null) {
          continue;
        }
        var value = values[i];
        if (utils.lessThan(value, boundValue)) {
          return true;
        } else if (value == boundValue) {
          continue;
        } else {
          return false;
        }
      }

      if (range.lowerOpen == true && equals) {
        return false;
      }
    }

    return true;
  }
}

sdb.Filter keyRangeFilter(dynamic keyPath, KeyRange range) {
  if (keyPath is String) {
    sdb.Filter lowerFilter;
    sdb.Filter upperFilter;
    List<sdb.Filter> filters = [];
    if (range.lower != null) {
      // only
      if (range.upper == range.lower &&
          range.lowerOpen != true &&
          range.lowerOpen != true) {
        return sdb.Filter.equal(keyPath, range.lower);
      }

      // lower bound
      if (range.lowerOpen == true) {
        if (keyPath is String) {
          lowerFilter = sdb.Filter.greaterThan(keyPath, range.lower);
        } else {
          throw 'TODO support keyPath array ${keyPath}';
        }
      } else {
        if (keyPath is String) {
          lowerFilter = sdb.Filter.greaterThanOrEquals(keyPath, range.lower);
        } else {
          throw 'TODO support keyPath array ${keyPath}';
        }
      }
      filters.add(lowerFilter);
    }
    // upper bound
    if (range.upper != null) {
      if (range.upperOpen == true) {
        if (keyPath is String) {
          upperFilter = sdb.Filter.lessThan(keyPath, range.upper);
        } else {
          throw 'TODO support keyPath array ${keyPath}';
        }
      } else {
        if (keyPath is String) {
          upperFilter = sdb.Filter.lessThanOrEquals(keyPath, range.upper);
        } else {
          throw 'TODO support keyPath array ${keyPath}';
        }
      }
      filters.add(upperFilter);
    }
    return sdb.Filter.and(filters);
  } else if (keyPath is List) {
    List keyList = keyPath;

    if (range.lower != null) {
      // only?
      if ((range.upper != null) &&
          (const ListEquality()
              .equals(range.lower as List, range.upper as List)) &&
          range.lowerOpen != true &&
          range.lowerOpen != true) {
        return sdb.Filter.and(List.generate(keyList.length,
            (i) => sdb.Filter.equal(keyList[i] as String, range.lower)));
      }
    }

    return KeyArrayRangeFilter(keyList, range);
  }
  throw 'keyPath $keyPath not supported';
}

// The null value for the key actually means any but null...
sdb.Filter keyFilter(dynamic keyPath, var key) {
  if (keyPath is String) {
    if (key == null) {
      // key must not be nulled
      return sdb.Filter.notEqual(keyPath, null);
    }
    return sdb.Filter.equal(keyPath, key);
  } else if (keyPath is List) {
    List keyList = keyPath;
    // No constraint on the key it just needs to exist
    // so every field must be non-null
    if (key == null) {
      return sdb.Filter.and(
          List.generate(keyList.length, (i) => keyFilter(keyList[i], null)));
    } else {
      List valueList = key;
      return sdb.Filter.and(List.generate(
          keyList.length, (i) => keyFilter(keyList[i], valueList[i])));
    }
  }
  throw 'keyPath $keyPath not supported';
}

sdb.Filter keyOrRangeFilter(dynamic keyPath, [keyOrRange]) {
  if (keyOrRange is KeyRange) {
    return keyRangeFilter(keyPath, keyOrRange);
  } else {
    return keyFilter(keyPath, keyOrRange);
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

abstract class KeyCursorSembastMixin implements Cursor {
  // set upon creation
  int recordIndex;
  BaseCursorControllerSembastMixin ctlr;

  ObjectStoreSembast get store => ctlr.store;

  IdbCursorMeta get meta => ctlr.meta;

  sdb.Record get record => ctlr.records[recordIndex];

  //
  // Idb
  //
  @override
  String get direction => meta.direction;

  @override
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

abstract class IndexCursorSembastMixin implements Cursor {
  IndexCursorControllerSembastMixin get indexCtlr;

  IndexSembast get index => indexCtlr.index;

  sdb.Record get record;

  ///
  /// Return the index key of the record
  ///
  @override
  Object get key {
    return mapValueAtKeyPath(record.value as Map, index.keyPath);
  }
}

abstract class CursorWithValueSembastMixin implements CursorWithValue {
  sdb.Record get record;

  @override
  Object get value => record.value;
}

class IndexKeyCursorSembast extends Object
    with KeyCursorSembastMixin, IndexCursorSembastMixin
    implements Cursor {
  @override
  IndexKeyCursorControllerSembast get indexCtlr =>
      ctlr as IndexKeyCursorControllerSembast;

  IndexKeyCursorSembast(IndexKeyCursorControllerSembast ctlr, int index) {
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

class IndexCursorWithValueSembast extends Object
    with KeyCursorSembastMixin, CursorWithValueSembastMixin {
  IndexCursorWithValueControllerSembast get indexCtlr =>
      ctlr as IndexCursorWithValueControllerSembast;

  IndexCursorWithValueSembast(
      BaseCursorControllerSembastMixin ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }

  ///
  /// Return the index key of the record
  ///
  @override
  Object get key =>
      mapValueAtKeyPath(record.value as Map, indexCtlr.index.keyPath);
}

class StoreCursorWithValueSembast extends Object
    with KeyCursorSembastMixin, CursorWithValueSembastMixin {
  StoreCursorWithValueSembast(
      BaseCursorControllerSembastMixin ctlr, int index) {
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

  List<sdb.SortOrder> get sortOrders;
}

abstract class IndexCursorControllerSembastMixin implements _ISdbCursor {
  IndexSembast index;

  IdbCursorMeta get meta;

  @override
  List<sdb.SortOrder> get sortOrders {
    return index.sortOrders(meta.ascending);
  }

  @override
  sdb.Filter get filter {
    return index.cursorFilter(meta.key, meta.range);
  }
}

abstract class StoreCursorControllerSembastMixin implements _ISdbCursor {
  ObjectStoreSembast get store;

  IdbCursorMeta get meta;

  @override
  List<sdb.SortOrder> get sortOrders {
    return store.sortOrders(meta.ascending);
  }

  @override
  sdb.Filter get filter {
    return store.cursorFilter(meta.key, meta.range);
  }
}

abstract class BaseCursorControllerSembastMixin<T extends Cursor>
    implements _ISdbCursor {
  IdbCursorMeta meta;

  ObjectStoreSembast get store;

// To implement for KeyCursor vs CursorWithValue
  T nextEvent(int index);

  List<sdb.Record> records;

  bool get done => currentIndex == null;
  int currentIndex = -1;
  StreamController<T> ctlr;

  void init() {
    ctlr = StreamController(sync: true);
  }

  Future autoNext() {
    return advance(1).then((_) {
      if (meta.autoAdvance && (!done)) {
        return autoNext();
      }
      return null;
    });
  }

  Future advance(int count) {
    currentIndex += count;
    if (currentIndex >= records.length) {
      currentIndex = null;
      return ctlr.close();
    }

    ctlr.add(nextEvent(currentIndex));
    return Future.value();
  }

  Future openCursor() {
    sdb.Filter filter = this.filter;
    List<sdb.SortOrder> sortOrders = this.sortOrders;
    sdb.Finder finder = sdb.Finder(filter: filter, sortOrders: sortOrders);
    return store.sdbStore.findRecords(finder).then((List<sdb.Record> records) {
      this.records = records;
      return autoNext();
    });
  }
}

abstract class KeyCursorControllerSembastMixin {
  StreamController<Cursor> get ctlr;

  Stream<Cursor> get stream => ctlr.stream;
}

abstract class CursorWithValueControllerSembastMixin {
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

class IndexKeyCursorControllerSembast extends Object
    with
        KeyCursorControllerSembastMixin,
        BaseCursorControllerSembastMixin<Cursor>,
        IndexCursorControllerSembastMixin {
  @override
  ObjectStoreSembast get store => index.store;

  IndexKeyCursorControllerSembast(IndexSembast index, IdbCursorMeta meta) {
    this.meta = meta;
    this.index = index;
    init();
  }

  @override
  Cursor nextEvent(int index) {
    IndexKeyCursorSembast cursor = IndexKeyCursorSembast(this, index);
    return cursor;
  }
}

class IndexCursorWithValueControllerSembast extends Object
    with
        CursorWithValueControllerSembastMixin,
        BaseCursorControllerSembastMixin<CursorWithValue>,
        IndexCursorControllerSembastMixin {
  @override
  ObjectStoreSembast get store => index.store;

  IndexCursorWithValueControllerSembast(
      IndexSembast index, IdbCursorMeta meta) {
    this.meta = meta;
    this.index = index;
    init();
  }

  @override
  CursorWithValue nextEvent(int index) {
    IndexCursorWithValueSembast cursor =
        IndexCursorWithValueSembast(this, index);
    return cursor;
  }
}

class StoreCursorWithValueControllerSembast extends Object
    with
        CursorWithValueControllerSembastMixin,
        BaseCursorControllerSembastMixin<CursorWithValue>,
        StoreCursorControllerSembastMixin {
  @override
  ObjectStoreSembast store;

  StoreCursorWithValueControllerSembast(this.store, IdbCursorMeta meta) {
    this.meta = meta;
    init();
  }

  @override
  CursorWithValue nextEvent(int index) {
    StoreCursorWithValueSembast cursor =
        StoreCursorWithValueSembast(this, index);
    return cursor;
  }
}

List<sdb.SortOrder> keyPathSortOrders(dynamic keyPath, bool ascending) {
  if (keyPath is String) {
    return [sdb.SortOrder(keyPath, ascending)];
  } else if (keyPath is List) {
    List keyList = keyPath;
    return List.generate(
        keyList.length, (i) => sdb.SortOrder(keyList[i] as String, ascending));
  }
  throw 'invalid keyPath $keyPath';
}
