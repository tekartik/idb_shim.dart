// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sembast/sembast_import.dart' as sdb;
import 'package:idb_shim/src/sembast/sembast_index.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

abstract class KeyCursorSembastMixin implements Cursor {
  // set upon creation
  late int recordIndex;
  late BaseCursorControllerSembastMixin ctlr;

  ObjectStoreSembast get store => ctlr.store;

  IdbCursorMeta get meta => ctlr.meta;

  RecordSnapshotSembast get record => ctlr.records![recordIndex];

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

  // Make sure advance does not pause the transaction
  @override
  void next() => store.transaction!.execute(() => advance(1));

  @override
  Future delete() async {
    await store.delete(record.primaryKey);
    var i = recordIndex + 1;
    while (i < ctlr.records!.length) {
      if (ctlr.records![i].primaryKey == record.primaryKey) {
        ctlr.records!.removeAt(i);
      } else {
        i++;
      }
    }
  }

  @override
  Object get key => record.key;

  @override
  Object get primaryKey => record.primaryKey;

  @override
  Future<void> update(Object value) async {
    // Keep the transaction alive
    // value is converted in put
    await store.put(value, store.getUpdateKeyIfNeeded(value, primaryKey));
    await store.transaction!.execute(() async {
      var sdbSnapshot =
          await store.sdbStore.record(primaryKey).getSnapshot(store.sdbClient);
      // Also update all records in the current list...
      var i = recordIndex + 1;
      while (i < ctlr.records!.length) {
        if (ctlr.records![i].primaryKey == record.primaryKey) {
          if (sdbSnapshot == null) {
            ctlr.records!.removeAt(i);
          } else {
            ctlr.records![i] =
                IndexRecordSnapshotSembast(ctlr.records![i].key, sdbSnapshot);
            i++;
          }
        } else {
          i++;
        }
      }
    });
  }
}

abstract class IndexCursorSembastMixin implements Cursor {
  IndexCursorControllerSembastMixin get indexCtlr;

  IndexSembast get index => indexCtlr.index;

  RecordSnapshotSembast get record;
}

abstract class CursorWithValueSembastMixin implements CursorWithValue {
  ObjectStoreSembast get store;
  RecordSnapshotSembast get record;

  @override
  Object get value => store.recordToValue(record.snapshot)!;
}

class IndexKeyCursorSembast extends Object
    with KeyCursorSembastMixin, IndexCursorSembastMixin
    implements Cursor {
  @override
  IndexKeyCursorControllerSembast get indexCtlr =>
      ctlr as IndexKeyCursorControllerSembast;

  IndexKeyCursorSembast(IndexKeyCursorControllerSembast ctlr, int index) {
    this.ctlr = ctlr;
    recordIndex = index;
  }
}

class IndexCursorWithValueSembast extends Object
    with KeyCursorSembastMixin, CursorWithValueSembastMixin {
  IndexCursorWithValueControllerSembast get indexCtlr =>
      ctlr as IndexCursorWithValueControllerSembast;

  IndexCursorWithValueSembast(
      BaseCursorControllerSembastMixin ctlr, int index) {
    this.ctlr = ctlr;
    recordIndex = index;
  }
}

class StoreCursorWithValueSembast extends Object
    with KeyCursorSembastMixin, CursorWithValueSembastMixin {
  StoreCursorWithValueSembast(
      BaseCursorControllerSembastMixin ctlr, int index) {
    this.ctlr = ctlr;
    recordIndex = index;
  }
}

class StoreKeyCursorSembast extends Object with KeyCursorSembastMixin {
  StoreKeyCursorSembast(BaseCursorControllerSembastMixin ctlr, int index) {
    this.ctlr = ctlr;
    recordIndex = index;
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

abstract class _ICursorSembast {
  sdb.Filter get filter;

  List<sdb.SortOrder> get sortOrders;

  /// The list of snapshot
  List<RecordSnapshotSembast>? records;

  /// Set the resulting records, special handling needed for multiEntry index
  void setRecords(List<sdb.RecordSnapshot<Object, Object>> records);
}

class RecordSnapshotSembast {
  final sdb.RecordSnapshot<Object, Object> snapshot;
  Object get primaryKey => snapshot.key;
  Object get key => primaryKey;

  RecordSnapshotSembast(this.snapshot);

  @override
  String toString() => '$snapshot';
}

class IndexRecordSnapshotSembast extends RecordSnapshotSembast {
  @override
  final Object key;
  IndexRecordSnapshotSembast(
      this.key, sdb.RecordSnapshot<Object, Object> snapshot)
      : super(snapshot);

  @override
  String toString() => '$key $snapshot';
}

abstract class IndexCursorControllerSembastMixin implements _ICursorSembast {
  late IndexSembast index;

  IdbCursorMeta get meta;

  @override
  List<sdb.SortOrder> get sortOrders {
    return index.sortOrders(meta.ascending);
  }

  @override
  sdb.Filter get filter {
    return index.cursorFilter(meta.key, meta.range);
  }

  /// To override for index
  @override
  void setRecords(List<sdb.RecordSnapshot<Object, Object>> records) {
    if (index.multiEntry) {
      /// Duplicate some records
      var list = <IndexRecordSnapshotSembast>[];
      for (var record in records) {
        var keys =
            valueAsSet(mapValueAtKeyPath(record.value as Map?, index.keyPath));
        if (keys != null) {
          for (var key in keys) {
            list.add(IndexRecordSnapshotSembast(decodeKey(key!), record));
          }
        }
      }
      list.sort((a, b) =>
          fixCompareValue(compareKeys(a.key, b.key), asc: meta.ascending));
      this.records = list;
    } else {
      this.records = records
          .map((snapshot) => IndexRecordSnapshotSembast(
              mapValueAtKeyPath(snapshot.value as Map, index.keyPath)!,
              snapshot))
          .toList(growable: false);
    }
  }
}

abstract class StoreCursorControllerSembastMixin implements _ICursorSembast {
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
    implements _ICursorSembast {
  late IdbCursorMeta meta;

  ObjectStoreSembast get store;

// To implement for KeyCursor vs CursorWithValue
  T nextEvent(int index);

  @override
  List<RecordSnapshotSembast>? records;

  bool get done => currentIndex == null;
  int? currentIndex = -1;
  late StreamController<T> ctlr;

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
    currentIndex = currentIndex! + count;
    if (currentIndex! >= records!.length) {
      currentIndex = null;
      return ctlr.close();
    }

    ctlr.add(nextEvent(currentIndex!));
    return Future.value();
  }

  Future openCursor() async {
    final filter = this.filter;
    final sortOrders = this.sortOrders;
    final finder = sdb.Finder(filter: filter, sortOrders: sortOrders);
    var records = await store.sdbStore.find(store.sdbClient, finder: finder);
    setRecords(records);

    // Handle first
    return autoNext();
  }

  @override
  void setRecords(List<sdb.RecordSnapshot<Object, Object>> records) {
    this.records = records
        .map((snapshot) => RecordSnapshotSembast(snapshot))
        .toList(growable: false);
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
    final cursor = IndexKeyCursorSembast(this, index);
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
    final cursor = IndexCursorWithValueSembast(this, index);
    return cursor;
  }
}

class StoreKeyCursorControllerSembast extends Object
    with
        KeyCursorControllerSembastMixin,
        BaseCursorControllerSembastMixin<Cursor>,
        StoreCursorControllerSembastMixin {
  @override
  ObjectStoreSembast store;

  StoreKeyCursorControllerSembast(this.store, IdbCursorMeta meta) {
    this.meta = meta;
    init();
  }

  @override
  Cursor nextEvent(int index) {
    var cursor = StoreKeyCursorSembast(this, index);
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
    final cursor = StoreCursorWithValueSembast(this, index);
    return cursor;
  }
}

/// Key path must have been escaped before
List<sdb.SortOrder> keyPathSortOrders(dynamic keyPath, bool ascending) {
  if (keyPath is String) {
    return [sdb.SortOrder(keyPath, ascending)];
  } else if (keyPath is List) {
    final keyList = keyPath;
    return List.generate(
        keyList.length, (i) => sdb.SortOrder(keyList[i] as String, ascending));
  }
  throw 'invalid keyPath $keyPath';
}
