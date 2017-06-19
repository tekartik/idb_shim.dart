part of idb_shim_sembast;

class _SdbObjectStore extends ObjectStore with ObjectStoreWithMetaMixin {
  final IdbObjectStoreMeta meta;
  final _SdbTransaction transaction;
  _SdbDatabase get database => transaction.database;
  sdb.Database get sdbDatabase => database.db;
  sdb.Store sdbStore;

  _SdbObjectStore(this.transaction, this.meta) {
    sdbStore = sdbDatabase.getStore(name);
  }

  Future inWritableTransaction(Future computation()) {
    if (transaction.meta.mode != idbModeReadWrite) {
      return new Future.error(new DatabaseReadOnlyError());
    }
    return inTransaction(computation);
  }

  Future inTransaction(computation()) {
    return transaction.execute(computation);
//    transaction.txn

//    // create the transaction if needed
//    // make it async so that we get the result of the action before transaction completion
//    Completer completer = new Completer();
//    transaction._completed = completer.future;
//
//    return sdbStore.inTransaction(() {
//      return computation();
//    }).then((result) {
//      completer.complete();
//      return result;
//
//    })
//    return sdbStore.inTransaction(() {
//      return new Future.sync(computation).then((result) {
//
//      });
//    });
  }

  /// extract the key from the key itself or from the value
  /// it is a map and keyPath is not null
  dynamic _getKey(value, [key]) {
    if ((keyPath != null) && (value is Map)) {
      var keyInValue = value[keyPath];
      if (keyInValue != null) {
        if (key != null) {
          throw new ArgumentError(
              "both key ${key} and inline keyPath ${keyInValue} are specified");
        } else {
          return keyInValue;
        }
      }
    }

    if (key == null && (!autoIncrement)) {
      throw new DatabaseError(
          'neither keyPath nor autoIncrement set and trying to add object without key');
    }

    return key;
  }

  _put(value, key) {
    // Check all indexes
    List<Future> futures = [];
    if (value is Map) {
      meta.indecies.forEach((IdbIndexMeta indexMeta) {
        var fieldValue = value[indexMeta.keyPath];
        if (fieldValue != null) {
          sdb.Finder finder = new sdb.Finder(
              filter: new sdb.Filter.equal(indexMeta.keyPath, fieldValue),
              limit: 1);
          futures.add(sdbStore.findRecord(finder).then((sdb.Record record) {
            // not ourself
            if ((record != null) &&
                (record.key != key) //
                &&
                ((!indexMeta.multiEntry) && indexMeta.unique)) {
              throw new DatabaseError(
                  "key '${fieldValue}' already exists in ${record} for index ${indexMeta}");
            }
          }));
        }
      });
    }
    return Future.wait(futures).then((_) {
      return sdbStore.put(value, key);
    });
  }

  @override
  Future add(value, [key]) {
    return inWritableTransaction(() {
      key = _getKey(value, key);

      if (key != null) {
        return sdbStore.get(key).then((existingValue) {
          if (existingValue != null) {
            throw new DatabaseError(
                'Key ${key} already exists in the object store');
          }
          return _put(value, key);
        });
      } else {
        return _put(value, key);
      }
    });
  }

  @override
  Future clear() {
    return inWritableTransaction(() {
      return sdbStore.clear();
    }).then((_) {
      return null;
    });
  }

  _storeKeyOrRangeFilter([key_OR_range]) {
    return _keyOrRangeFilter(sdb.Field.key, key_OR_range);
  }

  @override
  Future<int> count([key_OR_range]) {
    return inTransaction(() {
      return sdbStore.count(_storeKeyOrRangeFilter(key_OR_range));
    });
  }

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    IdbIndexMeta indexMeta =
        new IdbIndexMeta(name, keyPath, unique, multiEntry);
    meta.createIndex(database.meta, indexMeta);
    return new _SdbIndex(this, indexMeta);
  }

  @override
  void deleteIndex(String name) {
    meta.deleteIndex(database.meta, name);
  }

  @override
  Future delete(key) {
    return inWritableTransaction(() {
      return sdbStore.delete(key).then((_) {
        // delete returns null
        return null;
      });
    });
  }

  dynamic _recordToValue(sdb.Record record) {
    if (record == null) {
      return null;
    }
    var value = record.value;
    // Add key if _keyPath is not null
    if ((keyPath != null) && (value is Map)) {
      value[keyPath] = record.key;
    }

    return value;
  }

  @override
  Future getObject(key) {
    checkKeyParam(key);
    return inTransaction(() {
      return sdbStore.getRecord(key).then((sdb.Record record) {
        return _recordToValue(record);
      });
    });
  }

  @override
  Index index(String name) {
    IdbIndexMeta indexMeta = meta.index(name);
    return new _SdbIndex(this, indexMeta);
  }

  sdb.SortOrder sortOrder(bool ascending) {
    return new sdb.SortOrder(keyField, ascending);
  }

  sdb.Filter cursorFilter(key, KeyRange range) {
    if (range != null) {
      return _keyRangeFilter(keyField, range);
    } else {
      return _keyFilter(keyField, key);
    }
  }

  String get keyField => keyPath != null ? keyPath : sdb.Field.key;

  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    IdbCursorMeta cursorMeta =
        new IdbCursorMeta(key, range, direction, autoAdvance);
    _SdbStoreCursorWithValueController ctlr =
        new _SdbStoreCursorWithValueController(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Future put(value, [key]) {
    return inWritableTransaction(() {
      return _put(value, _getKey(value, key));
    });
  }
}
