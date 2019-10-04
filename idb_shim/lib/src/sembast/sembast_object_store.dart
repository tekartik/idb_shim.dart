import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_validation.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sembast/sembast_cursor.dart';
import 'package:idb_shim/src/sembast/sembast_database.dart';
import 'package:idb_shim/src/sembast/sembast_filter.dart';
import 'package:idb_shim/src/sembast/sembast_index.dart';
import 'package:idb_shim/src/sembast/sembast_transaction.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sdb;

class ObjectStoreSembast extends ObjectStore with ObjectStoreWithMetaMixin {
  @override
  final IdbObjectStoreMeta meta;

  final TransactionSembast transaction;

  DatabaseSembast get database => transaction.database;

  sdb.Database get sdbDatabase => database.db;

  sdb.Transaction get sdbTransaction => transaction.sdbTransaction;

  sdb.DatabaseClient _sdbClient;
  sdb.StoreRef<dynamic, dynamic> _sdbStore;

  // Lazy computat
  sdb.StoreRef<dynamic, dynamic> get sdbStore =>
      _sdbStore ??= sdb.StoreRef<dynamic, dynamic>(name);

  // lazy creation
  // If we are not in a transaction that's likely during open
  sdb.DatabaseClient get sdbClient =>
      _sdbClient ??= (sdbTransaction ?? sdbDatabase) as sdb.DatabaseClient;

  ObjectStoreSembast(this.transaction, this.meta) {
    // Don't compute sdbStore yet we don't have the transaction
    /*
    // If we are not in a transaction that's likely during open
    sdbStore = transaction.sdbTransaction == null
        ? sdbDatabase.getStore(name)
        : transaction.sdbTransaction.getStore(name);
        */
  }

  Future<T> _inWritableTransaction<T>(FutureOr<T> computation()) {
    if (transaction.meta.mode != idbModeReadWrite) {
      return Future.error(DatabaseReadOnlyError());
    }
    return inTransaction(computation);
  }

  /// Run a computation in a transaction.
  Future<T> inTransaction<T>(FutureOr<T> computation()) {
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
  dynamic getKeyImpl(value, [key]) {
    if (keyPath != null) {
      if (key != null) {
        throw ArgumentError(
            "The object store uses in-line keys and the key parameter '$key' was provided");
      }
      if (value is Map) {
        key = mapValueAtKeyPath(value, keyPath);
      }
    }

    if (key == null && (!autoIncrement)) {
      throw DatabaseError(
          'neither keyPath nor autoIncrement set and trying to add object without key');
    }

    return key;
  }

  /// Only key the if key path is null
  dynamic getUpdateKeyIfNeeded(value, [key]) {
    if (keyPath == null) {
      return key;
    }
    return null;
  }

  Future _put(value, key) {
    // Check all indexes
    List<Future> futures = [];
    if (value is Map) {
      meta.indecies.forEach((IdbIndexMeta indexMeta) {
        var fieldValue = mapValueAtKeyPath(value, indexMeta.keyPath);
        if (fieldValue != null) {
          sdb.Finder finder = sdb.Finder(
              filter: keyFilter(indexMeta.keyPath, fieldValue, false),
              limit: 1);
          futures
              .add(sdbStore.findFirst(sdbClient, finder: finder).then((record) {
            // not ourself
            if ((record != null) &&
                (record.key != key) //
                &&
                ((!indexMeta.multiEntry) && indexMeta.unique)) {
              throw DatabaseError(
                  "key '$fieldValue' already exists in $record for index $indexMeta");
            }
          }));
        }
      });
    }
    return Future.wait(futures).then((_) {
      if (key == null) {
        return sdbStore.add(sdbClient, value);
      } else {
        return sdbStore.record(key).put(sdbClient, value).then((_) => key);
      }
    });
  }

  @override
  Future add(value, [key]) {
    return _inWritableTransaction(() {
      key = getKeyImpl(value, key);

      if (key != null) {
        return sdbStore.record(key).get(sdbClient).then((existingValue) {
          if (existingValue != null) {
            throw DatabaseError('Key $key already exists in the object store');
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
    return _inWritableTransaction(() {
      return sdbStore.delete(sdbClient);
    }).then((_) {
      return null;
    });
  }

  sdb.Filter _storeKeyOrRangeFilter([keyOrRange]) {
    return keyOrRangeFilter(sdb.Field.key, keyOrRange, false);
  }

  @override
  Future<int> count([keyOrRange]) {
    return inTransaction(() {
      return sdbStore.count(sdbClient,
          filter: _storeKeyOrRangeFilter(keyOrRange));
    });
  }

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    IdbIndexMeta indexMeta = IdbIndexMeta(name, keyPath, unique, multiEntry);
    meta.createIndex(database.meta, indexMeta);
    return IndexSembast(this, indexMeta);
  }

  @override
  void deleteIndex(String name) {
    meta.deleteIndex(database.meta, name);
  }

  @override
  Future delete(key) {
    return _inWritableTransaction(() {
      return sdbStore.record(key).delete(sdbClient).then((_) {
        // delete returns null
        return null;
      });
    });
  }

  dynamic _recordToValue(sdb.RecordSnapshot record) {
    if (record == null) {
      return null;
    }
    var value = record.value;
    // Add key if _keyPath is not null
    if ((keyPath != null) && (value is Map)) {
      value = cloneValue(value, keyPath, record.key);
    }

    return value;
  }

  @override
  Future getObject(key) {
    checkKeyParam(key);
    return inTransaction(() {
      return sdbStore.record(key).getSnapshot(sdbClient).then((record) {
        return _recordToValue(record);
      });
    });
  }

  @override
  Index index(String name) {
    IdbIndexMeta indexMeta = meta.index(name);
    return IndexSembast(this, indexMeta);
  }

  /// Get the sembast sort orders.
  List<sdb.SortOrder> sortOrders(bool ascending) =>
      keyPathSortOrders(keyField, ascending);

  /// Convert to a sembast filter.
  sdb.Filter cursorFilter(key, KeyRange range) {
    if (range != null) {
      return keyRangeFilter(keyField, range, false);
    } else {
      return keyFilter(keyField, key, false);
    }
  }

  /// Get the keyPath or default sdb key
  dynamic get keyField => keyPath ?? sdb.Field.key;

  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    IdbCursorMeta cursorMeta =
        IdbCursorMeta(key, range, direction, autoAdvance);
    StoreCursorWithValueControllerSembast ctlr =
        StoreCursorWithValueControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Stream<Cursor> openKeyCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    IdbCursorMeta cursorMeta =
        IdbCursorMeta(key, range, direction, autoAdvance);
    var ctlr = StoreKeyCursorControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Future put(value, [key]) {
    return _inWritableTransaction(() {
      return _put(value, getKeyImpl(value, key));
    });
  }
}
