part of idb_memory;


class _MemoryObjectStoreMeta {
  MemoryObjectStore store;
  String name;
  MemoryPrimaryIndex primaryIndex;


  // List<dynamic> items = new List();
  //Map<dynamic, MemoryItem> itemsByKey = new Map();

  Map<String, _MemoryIndex> indeciesByName = new Map();
  List<_MemoryIndex> indecies = new List();

  void addIndex(_MemoryIndex index) {
    indecies.add(index);
    if (index.name != null) {
      indeciesByName[index.name] = index;
    }
  }
  _MemoryObjectStoreMeta(this.name, String keyPath, bool autoIncrement) {
    if (autoIncrement == null) {
      autoIncrement = false;
    }

    if (autoIncrement) {
      primaryIndex = new AutoIncrementMemoryPrimaryIndex(this, keyPath);
    } else {
      primaryIndex = new MemoryPrimaryIndex(this, keyPath);
    }
    addIndex(primaryIndex);
  }
}
class MemoryObjectStore extends ObjectStore {
  _MemoryTransaction transaction;
  _MemoryObjectStoreMeta _meta;



  MemoryObjectStore(this.transaction, this._meta) {
    _meta.store = this;
    if (transaction == null) {
      throw new StateError("cannot create objectStore outside of a versionChangedEvent");
    }
  }

  updateAllIndecies(_MemoryItem item, [_MemoryItem oldItem]) {
    _meta.indecies.forEach((_MemoryIndex index) {
      index.updateIndex(item, oldItem);
    });
  }
  
  checkAndUpdateAllIndecies(_MemoryItem item, [_MemoryItem oldItem]) {
      _meta.indecies.forEach((_MemoryIndex index) {
        index.updateIndex(item, oldItem);
      });
    }

  removeAllIndecies(_MemoryItem item) {
    _meta.indecies.forEach((_MemoryIndex index) {
      index.removeIndex(item);
    });
  }

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    _MemoryIndex index = new _MemoryIndex(_meta, name, keyPath, unique, multiEntry);
    _meta.addIndex(index);
    return index;
  }

  @override
  String get keyPath => _meta.primaryIndex.keyPath;
  
  bool get autoIncrement => _meta.primaryIndex is AutoIncrementMemoryPrimaryIndex;

  Future _checkStore(computation()) {
    if (database.version < database.dataVersion) {
      transaction.memoryDatabase._error = new _MemoryError(_MemoryError.DATABASE_UPGRADED_ERROR_CODE, "database upgraded from ${database.version} to ${database.dataVersion}");
      if (database.onVersionChangeCtlr != null) {
        database.onVersionChangeCtlr.add(new _MemoryVersionChangeEvent(database, database.version, database.dataVersion));
      }
    }
    _MemoryError error = transaction.memoryDatabase._error;
    if (error != null) {
      return new Future.error(error);

    }
    //    if (keyPath == null && !autoIncrement) {
    //      throw new ArgumentError("neither keyPath nor autoIncrement set");
    //    }
    return new Future.sync(computation);
  }


  Future inTransaction(computation()) {
    return _checkStore(() {
      return transaction._active(() {
        return transaction._enqueue(computation);
      });
    });
  }

  Future inWritableTransaction(computation()) {
    return inTransaction(() {
      if (transaction._mode != IDB_MODE_READ_WRITE) {
        return new Future.error(new DatabaseReadOnlyError());
      }
      return computation();
    });
  }

  @override
  Future add(dynamic value, [dynamic key]) {

    return inWritableTransaction(() {
      if (key == null) {
        if (keyPath != null) {
          key = value[keyPath];
        } else {
          if (!autoIncrement) {
            throw new ArgumentError("neither keyPath nor autoIncrement set and trying to add object without key");
          }
        }
      } else {
        if (!checkKeyValue(keyPath, key, value)) {
          throw new ArgumentError("both key $key and inline keyPath ${value[keyPath]}");
        }
      }
      dynamic newKey = _meta.primaryIndex.getKey(key);

      // when keyPath is specified in the index, add it to the value
      _MemoryItem item = new _MemoryItem(newKey, value, keyPath);
      
      if (_meta.primaryIndex.getSync(newKey) != null) {
        throw new _MemoryError(_MemoryError.KEY_ALREADY_EXISTS, 'Key already exists in the object store');
      }
      _meta.primaryIndex.setSync(newKey, item);
      // Add each indecies
      //checkAndUpdateAllIndecies(item);
      updateAllIndecies(item);
      return newKey;
    });
  }

  _MemoryItem _get(dynamic key) {
    if (key == null) {
      return null;
    }
    return _meta.primaryIndex.getSync(key);
  }

  @override
  Future getObject(dynamic key) {
    return inTransaction(() {
      _MemoryItem item = _get(key);
      if (item == null) {
        return null;
      }
      return item.value;
    });
  }

  @override
  Future clear() {
    return inWritableTransaction(() {
      List keys = new List.from(_meta.primaryIndex.keys);
      List<Future> futures = new List();
      keys.forEach((key) {
        _MemoryItem item = getSync(key);
        removeAllIndecies(item);
      });
    });
  }

  _MemoryDatabase get database => (transaction.database as _MemoryDatabase);

  @override
  Future put(value, [key]) {
    if (key == null) {
      return add(value, key);
    }
    return inWritableTransaction(() {
      // find key if any
      if (key == null) {
        key = value[_meta.primaryIndex.keyPath];
      }

      _MemoryItem oldItem = _get(key);
      if (oldItem == null) {
        return add(value, key);
      }

      _MemoryItem item = new _MemoryItem(key, value, _meta.primaryIndex.keyPath);
      updateAllIndecies(item, oldItem);

      return key;
    });
  }

  _MemoryItem getSync(key) {
    return _meta.primaryIndex.getSync(key);
  }

  @override
  Future delete(key) {
    return inWritableTransaction(() {
      _MemoryItem item = getSync(key);
      if (item != null) {
        removeAllIndecies(item);
      }
    });
  }

  Index index(String name) {
    Index index = _meta.indeciesByName[name];
    if (index == null) {
      throw new ArgumentError("index $name not found");
    }
    return index;

  }

  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    return _meta.primaryIndex.openCursor(key: key, range: range, direction: direction, autoAdvance: autoAdvance);
  }

  @override
  Future<int> count([key_OR_range]) {
    return _meta.primaryIndex.count(key_OR_range);
  }
  
  @override
  String get name => _meta.name;
}
