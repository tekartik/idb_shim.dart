part of idb_shim_memory;

class _MemoryItems {
  Map<dynamic, _MemoryItem> _items = new Map(); // map by primary key
  List<dynamic> keys = new List(); // ordered
  void add(_MemoryItem item) {
    _items[item.key] = item;
    keys.add(item.key);
    keys.sort();
  }
  void remove(_MemoryItem item) {
    _items.remove(item.key);
    keys.remove(item.key);
  }
  _MemoryItem get first {
    // give a random one for now
    return _items[keys.first];
  }

  int get length => _items.length;

  bool get isEmpty => _items.isEmpty;

  toString() => _items.toString();

  _MemoryItem getAtIndex(int i) {
    return getByKey(keys[i]);
  }
  // By primary key
  _MemoryItem getByKey(key) {
    return _items[key];
  }
}

class _MemoryIndex extends Index {
  _MemoryObjectStoreMeta data;
  MemoryObjectStore get store => data.store;
  String name;
  String keyPath;
  bool unique;
  bool multiEntry;

  _MemoryTransaction get transaction => store.transaction;

  // Ordered keys
  List keys = new List();

  Map<dynamic, _MemoryItems> itemsByKey = new Map();
  _MemoryIndex(this.data, this.name, this.keyPath, this.unique, this.multiEntry) {
    // Build the index based on the existing
    // TODO
    multiEntry = multiEntry == true;
    unique = unique == true;
  }

  List filterKeysByKeyOrRange(key_OR_range) {
    if (key_OR_range == null) {
      return keys;
    } else if (key_OR_range is KeyRange) {
      return filterKeysByRange(key_OR_range);
    } else {
      return filterKeysByKey(key_OR_range);
    }
  }

  List filterKeys(key, KeyRange range) {
    List _keys;
    if (range != null) {
      _keys = filterKeysByRange(range);
    } else if (key != null) {
      _keys = filterKeysByKey(key);
    } else {
      _keys = keys;
    }
    return _keys;
  }

  List filterKeysByRange(KeyRange range) {
    if (range == null) {
      return keys;
    } else {
      // Apply range
      List keys = new List();
      this.keys.forEach((key) {
        if (range.contains(key)) {
          //print('$key ok');
          keys.add(key);
        }
      });
      return keys;
    }
  }

  List filterKeysByKey(key) {

    // Apply range
    List keys = [key];
    return keys;
  }

  _MemoryItems getItemsSync(key) {
    return itemsByKey[key];
  }

  _MemoryItem getSync(key) {
    _MemoryItems items = getItemsSync(key);
    if (items == null) {
      return null;
    }
    return items.first;
  }

  _MemoryItems getOrAdd(key, _MemoryItem item) {
    _MemoryItems items = itemsByKey[key];
    if (items == null) {
      items = new _MemoryItems();
      itemsByKey[key] = items;
    }
    items.add(item);
    return items;
  }
  void setSync(key, _MemoryItem item) {
    getOrAdd(key, item);
  }

  Future inTransaction(computation()) {
    return store.inTransaction(computation);
  }

  Future get(key) {
    return inTransaction(() {
      return _MemoryItem.safeValue(getSync(key));
    });
  }

  Future getKey(key) {
    return inTransaction(() {
      return _MemoryItem.safeKey(getSync(key));
    });
  }

  dynamic getItemKey(_MemoryItem item) {
    if (keyPath == null) {
      return item.key;
    }
    return item[keyPath];
  }

  @override
  Future<int> count([key_OR_range]) {
    return inTransaction(() {
      List _keys = filterKeysByKeyOrRange(key_OR_range);

      int count = 0;
      for (var key in _keys) {
        _MemoryItems items = getItemsSync(key);
        if (items != null) {
          count += items.length;
        }
      }
      return count;
    });
  }

//  _void checkUnique(var key, _MemoryItem item, _MemoryItem oldItem) {
//
//  }
//  void updateIndex(_MemoryItem item, [_MemoryItem oldItem, check]) {
//    var key = getItemKey(item);
//        var oldKey;
//
//        if (oldItem != null) {
//          oldKey = getItemKey(oldItem);
//        } else {
//          oldItem = get
//        }
//
//        if (oldKey != null) {
//          if (oldKey != key) {
//            removeIndex(oldItem);
//          } else {
//            // check here
//            itemsByKey[key] = item;
//            return;
//          }
//        } else {
//          if (unique) {
//          if (keys.contains(key)) {
//
//          }
//          }
//          // Add and sort
//          keys.add(key);
//          keys.sort();
//
//          // check here
//          if (unique) {
//
//          }
//          itemsByKey[key] = item;
//        }
//  }
  void updateIndex(_MemoryItem item, [_MemoryItem oldItem]) {

    var key = getItemKey(item);
    var oldKey;

    if (oldItem != null) {
      oldKey = getItemKey(oldItem);
    }

    if (oldKey != null) {
      if (oldKey != key) {
        removeIndex(oldItem);
      }
    }

    // key must not be null
    if (key != null) {
      // Existing
      _MemoryItems items = getItemsSync(key);
      if (items != null) {
        // if (isP)
        if (unique) {
          if (items.first.key != item.key) {
            throw new _MemoryError(_MemoryError.KEY_ALREADY_EXISTS, "key already exists in ${this}");
          }
        }
//        if (items.getByKey())
      }


      // Add and sort
      if (!keys.contains(key)) {
        keys.add(key);
        keys.sort();
      }


      getOrAdd(key, item);
      //itemsByKey[key] = item;
    }

  }

  void removeIndex(_MemoryItem item) {
    var key = getItemKey(item);

    _MemoryItems items = itemsByKey[key];
    if (items == null) {

    } else {
      items.remove(item);
      if (items.isEmpty) {
        keys.remove(key);
      }
    }

    itemsByKey.remove(key);
  }


  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    if (direction == null) {
      direction = IDB_DIRECTION_NEXT;
    }
    if (autoAdvance == null) {
      autoAdvance = false;
    }

    _MemoryCursorWithValueController ctlr = new _MemoryCursorWithValueController(this, key, range, direction, autoAdvance);

    // future
    inTransaction(() {
      // must check for begin
      return ctlr.execute();
    });

    return ctlr.stream;
  }

  Stream<Cursor> openKeyCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    if (direction == null) {
      direction = IDB_DIRECTION_NEXT;
    }
    if (autoAdvance == null) {
      autoAdvance = true;
    }
    MemoryCursorController ctlr = new MemoryCursorController(this, //
    key, range, direction, autoAdvance);

    // future
    inTransaction(() {
      return transaction._enqueueFuture(ctlr.execute());
    });

    return ctlr.stream;
  }
}

class MemoryPrimaryIndex extends _MemoryIndex {
  dynamic getKey(key) {
    return key;
  }
  MemoryPrimaryIndex(_MemoryObjectStoreMeta data, String keyPath) : super(data, null, keyPath, true, false) {

  }
}

class AutoIncrementMemoryPrimaryIndex extends MemoryPrimaryIndex {
  int autoIncrementIndex = 0;
  AutoIncrementMemoryPrimaryIndex(_MemoryObjectStoreMeta data, String keyPath) : super(data, keyPath) {
  }

  @override
  dynamic getKey(key) {
    if (key != null) {
      if (key > autoIncrementIndex) {
        autoIncrementIndex = key;
      }
      return key;
    }
    return ++autoIncrementIndex;

  }


}
