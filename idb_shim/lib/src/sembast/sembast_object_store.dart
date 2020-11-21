import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_validation.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sembast/sembast_cursor.dart';
import 'package:idb_shim/src/sembast/sembast_database.dart';
import 'package:idb_shim/src/sembast/sembast_filter.dart';
import 'package:idb_shim/src/sembast/sembast_index.dart';
import 'package:idb_shim/src/sembast/sembast_transaction.dart';
import 'package:idb_shim/src/sembast/sembast_value.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sdb;

class ObjectStoreSembast extends ObjectStore with ObjectStoreWithMetaMixin {
  @override
  final IdbObjectStoreMeta? meta;

  final TransactionSembast? transaction;

  DatabaseSembast get database => transaction!.database;

  sdb.Database? get sdbDatabase => database.db;

  sdb.Transaction? get sdbTransaction => transaction!.sdbTransaction;

  sdb.DatabaseClient? _sdbClient;
  sdb.StoreRef<Object, Object>? _sdbStore;

  // Lazy computat
  sdb.StoreRef<Object, Object> get sdbStore =>
      _sdbStore ??= sdb.StoreRef<Object, Object>(name);

  // lazy creation
  // If we are not in a transaction that's likely during open
  sdb.DatabaseClient get sdbClient =>
      (_sdbClient ??= (sdbTransaction ?? sdbDatabase))!;

  ObjectStoreSembast(this.transaction, this.meta) {
    // Don't compute sdbStore yet we don't have the transaction
    /*
    // If we are not in a transaction that's likely during open
    sdbStore = transaction.sdbTransaction == null
        ? sdbDatabase.getStore(name)
        : transaction.sdbTransaction.getStore(name);
        */
  }

  Future<T> _inWritableTransaction<T>(FutureOr<T> Function() computation) {
    if (transaction!.meta!.mode != idbModeReadWrite) {
      return Future.error(DatabaseReadOnlyError());
    }
    return inTransaction(computation);
  }

  /// Run a computation in a transaction.
  Future<T> inTransaction<T>(FutureOr<T> Function() computation) {
    return transaction!.execute(computation);
  }

  /// extract the key from the key itself or from the value
  /// it is a map and keyPath is not null
  ///
  /// returns null for autoincrement
  Object? getKeyImpl(Object value, [Object? key]) {
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

  Future<Object> putImpl(Object? value, Object? key) {
    // Check all indexes
    final futures = <Future>[];
    if (value is Map) {
      meta!.indecies.forEach((IdbIndexMeta indexMeta) {
        var fieldValue = mapValueAtKeyPath(value, indexMeta.keyPath);
        if (fieldValue != null) {
          final finder = sdb.Finder(
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
        return sdbStore.add(sdbClient, value as Object);
      } else {
        return sdbStore
            .record(key)
            .put(sdbClient, value as Object)
            .then((_) => key);
      }
    });
  }

  @override
  Future<Object> add(Object value, [Object? key]) {
    value = toSembastValue(value);
    return _inWritableTransaction(() {
      key = getKeyImpl(value, key);

      if (key != null) {
        return sdbStore.record(key!).get(sdbClient).then((existingValue) {
          if (existingValue != null) {
            throw DatabaseError('Key $key already exists in the object store');
          }
          return putImpl(value, key!);
        });
      } else {
        return putImpl(value, null);
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
  Future<List<Object>> getAll([Object? keyOrRange, int? count]) {
    return inTransaction(() async {
      return (await sdbStore.find(
        sdbClient,
        finder: sdb.Finder(
            filter: _storeKeyOrRangeFilter(keyOrRange), limit: count),
      ))
          .map((r) => recordToValue(r)!)
          .toList(growable: false);
    });
  }

  @override
  Future<List<Object>> getAllKeys([Object? keyOrRange, int? count]) {
    return inTransaction(() async {
      return (await sdbStore.findKeys(
        sdbClient,
        finder: sdb.Finder(
            filter: _storeKeyOrRangeFilter(keyOrRange), limit: count),
      ));
    });
  }

  @override
  Index createIndex(String name, keyPath, {bool? unique, bool? multiEntry}) {
    final indexMeta = IdbIndexMeta(name, keyPath, unique, multiEntry);
    meta!.createIndex(database.meta, indexMeta);
    return IndexSembast(this, indexMeta);
  }

  @override
  void deleteIndex(String name) {
    meta!.deleteIndex(database.meta, name);
  }

  @override
  Future<void> delete(Object key) {
    return _inWritableTransaction(() {
      return sdbStore.record(key).delete(sdbClient).then((_) {
        // delete returns null
        return null;
      });
    });
  }

  /// Clone and convert
  Object? recordToValue(sdb.RecordSnapshot<Object, Object>? record) {
    if (record == null) {
      return null;
    } else {
      var value = record.value;
      // Add key if _keyPath is not null
      if ((keyPath != null) && (value is Map)) {
        value = cloneValue(value, keyPath, record.key);
      }

      return fromSembastValue(value);
    }
  }

  @override
  Future<Object?> getObject(key) {
    checkKeyParam(key);
    return inTransaction(() {
      return sdbStore.record(key).getSnapshot(sdbClient).then((record) {
        return recordToValue(record);
      });
    });
  }

  @override
  Index index(String name) {
    final indexMeta = meta!.index(name);
    return IndexSembast(this, indexMeta);
  }

  /// Get the sembast sort orders.
  List<sdb.SortOrder> sortOrders(bool ascending) =>
      keyPathSortOrders(keyField, ascending);

  /// Convert to a sembast filter.
  sdb.Filter cursorFilter(key, KeyRange? range) {
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
      {key, KeyRange? range, String? direction, bool? autoAdvance}) {
    final cursorMeta = IdbCursorMeta(key, range, direction, autoAdvance);
    final ctlr = StoreCursorWithValueControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Stream<Cursor> openKeyCursor(
      {key, KeyRange? range, String? direction, bool? autoAdvance}) {
    final cursorMeta = IdbCursorMeta(key, range, direction, autoAdvance);
    var ctlr = StoreKeyCursorControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Future<Object> put(Object value, [Object? key]) {
    value = toSembastValue(value);
    return _inWritableTransaction(() {
      return putImpl(value, getKeyImpl(value, key));
    });
  }
}
