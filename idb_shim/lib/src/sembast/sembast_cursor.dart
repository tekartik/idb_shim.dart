// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/src/sembast/sembast_import.dart' as sdb;
import 'package:idb_shim/src/sembast/sembast_index.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

abstract mixin class KeyCursorSembastMixin implements Cursor {
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
    store.transaction!.execute(() => ctlr._advance(count));
  }

  // Make sure advance does not pause the transaction
  @override
  void next() => advance(1);

  @override
  Future delete() async {
    if (this is! CursorWithValue) {
      // Do this to maintain the transaction...
      await store.transaction!.execute(() async {
        // Mimic Chrome behavior
        throw StateError(
            'Cannot call cursor.delete when openKeyCursor is used, try openCursor instead');
      });
    }

    var records = ctlr.records!;
    var primaryKey = record.primaryKey;
    var recordIndex = this.recordIndex;
    await store.transaction!.execute(() async {
      await store.txnDelete(primaryKey);
      var i = records.length - 1;
      while (i > recordIndex) {
        if (records[i].primaryKey == record.primaryKey) {
          ctlr.records!.removeAt(i);
        }
        i--;
      }
    });
  }

  @override
  Object get key => record.key;

  @override
  Object get primaryKey => record.primaryKey;

  @override
  Future<void> update(Object value) async {
    // Keep the transaction alive
    // value is converted in put
    var records = ctlr.records!;
    var primaryKey = this.primaryKey;
    var updateKey = store.getUpdateKeyIfNeeded(value, primaryKey);

    await store.transaction!.execute(() async {
      await store.txnPut(value, updateKey);
      var sdbSnapshot =
          await store.sdbStore.record(primaryKey).getSnapshot(store.sdbClient);
      // Also update all records in the current list...
      var i = recordIndex + 1;
      while (i < ctlr.records!.length) {
        if (records[i].primaryKey == primaryKey) {
          if (sdbSnapshot == null) {
            records.removeAt(i);
          } else {
            records[i] =
                IndexRecordSnapshotSembast(store, records[i].key, sdbSnapshot);
            i++;
          }
        } else {
          i++;
        }
      }
    });
  }
}

abstract mixin class IndexCursorSembastMixin implements Cursor {
  IndexCursorControllerSembastMixin get indexCtlr;

  IndexSembast get index => indexCtlr.index;

  RecordSnapshotSembast get record;
}

abstract mixin class CursorWithValueSembastMixin implements CursorWithValue {
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

  @override
  String toString() =>
      'KeyCursor(${logTruncateAny(primaryKey)}, ${logTruncateAny(key)})';
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

  @override
  String toString() =>
      'KeyWithValueCursor(${logTruncateAny(primaryKey)}, ${logTruncateAny(key)}): ${logTruncateAny(value)}';
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
  final ObjectStoreSembast idbStore;
  final sdb.RecordSnapshot<Object, Object> snapshot;

  Object get id => snapshot.key;

  Object get primaryKey =>
      idbStore.hasCompositeKey ? idbStore.getKeyImpl(snapshot.value)! : id;

  Object get key => primaryKey;

  RecordSnapshotSembast(this.idbStore, this.snapshot);

  @override
  String toString() => '$snapshot';
}

class IndexRecordSnapshotSembast extends RecordSnapshotSembast {
  @override
  final Object key;

  IndexRecordSnapshotSembast(ObjectStoreSembast idbStore, this.key,
      sdb.RecordSnapshot<Object, Object> snapshot)
      : super(idbStore, snapshot);

  @override
  String toString() => '$key $snapshot';
}

abstract mixin class IndexCursorControllerSembastMixin
    implements _ICursorSembast {
  late IndexSembast index;

  IdbCursorMeta get meta;

  @override
  List<sdb.SortOrder> get sortOrders {
    return index.sortOrders(meta.ascending);
  }

  ObjectStoreSembast get idbStore => index.store;

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
        var keys = valueAsSet((record.value as Map).getKeyValue(index.keyPath));
        if (keys != null) {
          for (var key in keys) {
            list.add(
                IndexRecordSnapshotSembast(idbStore, decodeKey(key!), record));
          }
        }
      }
      list.sort((a, b) =>
          fixCompareValue(compareKeys(a.key, b.key), asc: meta.ascending));
      this.records = list;
    } else {
      this.records = records
          .map((snapshot) => IndexRecordSnapshotSembast(idbStore,
              (snapshot.value as Map).getKeyValue(index.keyPath)!, snapshot))
          .toList(growable: false);
    }
  }
}

abstract mixin class StoreCursorControllerSembastMixin
    implements _ICursorSembast {
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

abstract mixin class BaseCursorControllerSembastMixin<T extends Cursor>
    implements _ICursorSembast {
  late IdbCursorMeta meta;

  bool get autoAdvance => meta.autoAdvance;

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

  void autoNext() {
    _advance(1);
    if (meta.autoAdvance && (!done)) {
      return autoNext();
    }
  }

  void _advance(int count) {
    currentIndex = currentIndex! + count;
    if (currentIndex! >= records!.length) {
      currentIndex = null;
      ctlr.close();

      return;
    }

    ctlr.add(nextEvent(currentIndex!));
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
        .map((snapshot) => RecordSnapshotSembast(store, snapshot))
        .toList(growable: false);
  }
}

abstract mixin class KeyCursorControllerSembastMixin {
  StreamController<Cursor> get ctlr;

  Stream<Cursor> get stream => ctlr.stream;
}

abstract mixin class CursorWithValueControllerSembastMixin {
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
