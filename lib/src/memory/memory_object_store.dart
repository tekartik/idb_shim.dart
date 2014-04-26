part of idb_memory;


class _MemoryObjectStoreData {
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
  _MemoryObjectStoreData(this.name, String keyPath, bool autoIncrement) {
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
  _MemoryObjectStoreData data;



  MemoryObjectStore(this.transaction, this.data) {
    data.store = this;
    if (transaction == null) {
      throw new StateError("cannot create objectStore outside of a versionChangedEvent");
    }
  }

  updateAllIndecies(_MemoryItem item, [_MemoryItem oldItem]) {
    data.indecies.forEach((_MemoryIndex index) {
      index.updateIndex(item, oldItem);
    });
  }

  removeAllIndecies(_MemoryItem item) {
    data.indecies.forEach((_MemoryIndex index) {
      index.removeIndex(item);
    });
  }

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    _MemoryIndex index = new _MemoryIndex(data, name, keyPath, unique, multiEntry);
    data.addIndex(index);
    return index;
  }

  String get keyPath => data.primaryIndex.keyPath;
  bool get autoIncrement => data.primaryIndex is AutoIncrementMemoryPrimaryIndex;

  Future _checkStoreOld() {
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
    return new Future.value();
  }

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
      return transaction._active.then((_) {
        return transaction._enqueue(() {
          return computation();
        });
      });
    });
  }

  @override
  Future add(dynamic value, [dynamic key]) {

    return inTransaction(() {
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
      dynamic newKey = data.primaryIndex.getKey(key);

      // when keyPath is specified in the index, add it to the value
      _MemoryItem item = new _MemoryItem(newKey, value, keyPath);
      data.primaryIndex.setSync(newKey, item);
      // Add each indecies
      updateAllIndecies(item);
      return newKey;
    });
  }

  _MemoryItem _get(dynamic key) {
    if (key == null) {
      return null;
    }
    return data.primaryIndex.getSync(key);
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
    return inTransaction(() {
      List keys = new List.from(data.primaryIndex.keys);
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
    return inTransaction(() {
      // find key if any
      if (key == null) {
        key = value[data.primaryIndex.keyPath];
      }

      _MemoryItem oldItem = _get(key);
      if (oldItem == null) {
        return add(value, key);
      }

      _MemoryItem item = new _MemoryItem(key, value, data.primaryIndex.keyPath);
      updateAllIndecies(item, oldItem);

      return key;
    });
  }

  _MemoryItem getSync(key) {
    return data.primaryIndex.getSync(key);
  }

  @override
  Future delete(key) {
    return inTransaction(() {
      _MemoryItem item = getSync(key);
      if (item != null) {
        removeAllIndecies(item);
      }
    });
  }

  Index index(String name) {
    Index index = data.indeciesByName[name];
    if (index == null) {
      throw new ArgumentError("index $name not found");
    }
    return index;

  }

  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    return data.primaryIndex.openCursor(key: key, range: range, direction: direction, autoAdvance: autoAdvance);
  }

  Future<int> count([key_OR_range]) {
    // TODO handle key or range
    return new Future.value(data.primaryIndex.keys.length);
  }
}
