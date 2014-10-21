part of idb_shim_memory;

abstract class _MemoryCommonCursor<T extends Cursor> {
  _MemoryItem _item;
  MemoryCursorBaseController _ctlr;

  void advance(int count) {
    // trigger transaction to avoid
    // failing
    _ctlr.advance(count);
  }
  void next([Object key]) {
    if (key != null) {
      throw new UnimplementedError();
    }
    advance(1);
  }

  MemoryObjectStore get _store => _ctlr.store;
  _MemoryIndex get _index => _ctlr.index;

  Object get value => _item.value;
  Object get key => _item[_index.keyPath];
  Object get primaryKey => _item.key;
  String get direction => _ctlr.direction;
  Future update(value) => _store.put(value, primaryKey);
  Future delete() => _store.delete(primaryKey);

  String toString() {
    return "cursor key $key value $value";
  }

}
class _MemoryCursor extends Cursor with _MemoryCommonCursor<Cursor> {

  _MemoryCursor(MemoryCursorController ctlr, _MemoryItem item) {
    this._ctlr = ctlr;
    this._item = item;
  }

}

class _MemoryCursorWithValue extends CursorWithValue with _MemoryCommonCursor<Cursor> {

  _MemoryCursorWithValue(_MemoryCursorWithValueController ctlr, _MemoryItem item) {
    this._ctlr = ctlr;
    this._item = item;
  }
}

abstract class MemoryCursorBaseController<T extends Cursor> {
  StreamController<T> ctlr = new StreamController(sync: true);
  String direction;
  bool autoAdvance;
  //int currentIndex = -1;
  int currentKeyIndex = -1;
  int currentItemIndex = null; // in the _MemoryItems
  int currentItemCount = null;
  _MemoryTransaction get transaction => store.transaction;
  _MemoryIndex index;
  MemoryObjectStore get store => index.data.store;

  // By default similar to the index, unless range is set
  List _keys;

  T newCursor(_MemoryItem item);

  MemoryCursorBaseController(this.index, key, KeyRange range, this.direction, this.autoAdvance) {
    if (direction == null) {
      direction = IDB_DIRECTION_NEXT;
    }
    if (autoAdvance == null) {
      autoAdvance = true;
    }

    _keys = index.filterKeys(key, range);
  }

  Future autoNext() {
    return transaction._enqueue(() {
      return advance(1).then((_) {
        if (autoAdvance) {
          autoNext();
        }
      });
    });
  }

  Future advance(int count) {
    return transaction._enqueue(() {
      if (currentItemIndex != null) {
        if (++currentItemIndex >= currentItemCount) {
          currentItemIndex = null;
        }
      }

      if (currentItemIndex == null) {
        currentKeyIndex += count;
        currentItemIndex = 0;
        if (currentKeyIndex >= _keys.length) {
          // Prevent auto advance
          autoAdvance = false;
          return ctlr.close();

        }
      }
      // Handle direction
      int realKeyIndex;
      switch (direction) {
        case IDB_DIRECTION_NEXT:
          realKeyIndex = currentKeyIndex;
          break;
        case IDB_DIRECTION_PREV:
          realKeyIndex = _keys.length - (currentKeyIndex + 1);
          break;
        default:
          throw new ArgumentError("direction '$direction' not supported");
      }
      _MemoryItems items = index.itemsByKey[_keys[realKeyIndex]];
      currentItemCount = items.length;


      int realItemIndex;
      switch (direction) {
        case IDB_DIRECTION_NEXT:
          realItemIndex = currentItemIndex;
          break;
        case IDB_DIRECTION_PREV:
          realItemIndex = currentItemCount - (currentItemIndex + 1);
          break;

      }
      //var key =
      ctlr.add(newCursor(items.getAtIndex(realItemIndex)));



    });
  }

  Stream<T> get stream => ctlr.stream;

  Future execute() {

    // Add operation to current transaction
    return autoNext();
  }
}
class _MemoryCursorWithValueController extends MemoryCursorBaseController<CursorWithValue> {
  //_MemoryCursorWithValue cursor;

  CursorWithValue newCursor(_MemoryItem item) {
    return new _MemoryCursorWithValue(this, item);
  }

  _MemoryCursorWithValueController(_MemoryIndex index, key, KeyRange range, String direction, bool autoAdvance) : super(index, key, range, direction, autoAdvance) {



  }



}

class MemoryCursorController extends MemoryCursorBaseController<Cursor> {

  Cursor newCursor(_MemoryItem item) {
    return new _MemoryCursor(this, item);
  }
  MemoryCursorController(_MemoryIndex index, key, KeyRange range, String direction, bool autoAdvance) : super(index, key, range, direction, autoAdvance) {
  }


}
