// ignore_for_file: public_member_api_docs

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
import 'package:sembast/sembast.dart' as sembast;

class ObjectStoreSembast extends ObjectStore with ObjectStoreWithMetaMixin {
  @override
  final IdbObjectStoreMeta? meta;

  final TransactionSembast? transaction;

  DatabaseSembast get database => transaction!.database;

  sembast.Database? get sembastDatabase => database.db;

  sembast.Transaction? get sembastTransaction =>
      transaction!.sembastTransaction;

  sembast.DatabaseClient? _sembastClient;
  sembast.StoreRef<Object, Object>? _sembastStore;

  // Lazy computed
  sembast.StoreRef<Object, Object> get sembastStore =>
      _sembastStore ??= sembast.StoreRef<Object, Object>(name);

  // lazy creation
  // If we are not in a transaction that's likely during open
  sembast.DatabaseClient get sembastClient =>
      (_sembastClient ??= (sembastTransaction ?? sembastDatabase))!;

  ObjectStoreSembast(this.transaction, this.meta) {
    // Don't compute sembastStore yet we don't have the transaction
    /*
    // If we are not in a transaction that's likely during open
    sembastStore = transaction.sembastTransaction == null
        ? sembastDatabase.getStore(name)
        : transaction.sembastTransaction.getStore(name);
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
          "The object store uses in-line keys and the key parameter '$key' was provided",
        );
      }
      if (value is Map) {
        key = value.getKeyValue(keyPath);
      }
    }

    if (key == null && (!autoIncrement)) {
      throw DatabaseError(
        'neither keyPath nor autoIncrement set and trying to add object without key',
      );
    }

    return key;
  }

  /// Fix the key in map
  /// Need for add without explicit key
  /// Not for composite key
  Object fixKeyInValueImpl(Object value, Object key) {
    if ((keyPath != null) && (value is Map)) {
      return cloneValue(value, keyPath as String, key);
    }
    return value;
  }

  /// Only key the if key path is null
  Object? getUpdateKeyIfNeeded(Object? value, [Object? key]) {
    if (keyPath == null) {
      return key;
    }
    return null;
  }

  Future<Object> putImpl(Object? value, Object? key) {
    // Check all indexes
    final futures = <Future>[];
    if (value is Map) {
      for (var indexMeta in meta!.indecies) {
        var fieldValue = value.getKeyValue(indexMeta.keyPath);
        if (fieldValue != null) {
          final finder = sembast.Finder(
            filter: keyFilter(indexMeta.keyPath, fieldValue, false),
            limit: 1,
          );
          futures.add(
            sembastStore.findFirst(sembastClient, finder: finder).then((
              record,
            ) {
              // not ourself
              if ((record != null) &&
                  (record.key != key) //
                  &&
                  ((!indexMeta.multiEntry) && indexMeta.unique)) {
                throw DatabaseError(
                  "key '$fieldValue' already exists in $record for index $indexMeta",
                );
              }
            }),
          );
        }
      }
    }
    return Future.wait(futures).then((_) async {
      if (key == null) {
        // Handle the case where a generated key is added
        // We are in a transaction so the key is safe
        // Make sure the key field is added
        var generatedKey = await sembastStore.generateIntKey(sembastClient);
        var fixedValue = fixKeyInValueImpl(value!, generatedKey);
        await sembastStore.record(generatedKey).add(sembastClient, fixedValue);
        return generatedKey;
      } else {
        var id = key;
        if (hasCompositeKey) {
          // Get existing if any
          var existing = await txnCompositeFindIdByKey(key);
          if (existing == null) {
            var generatedKey = await sembastStore.generateIntKey(sembastClient);
            id = generatedKey;
          } else {
            id = existing;
          }
        }
        return sembastStore
            .record(id)
            .put(sembastClient, value as Object)
            .then((_) => key);
      }
    });
  }

  sembast.Finder compositeFindByKeyFinder(Object key) {
    assert(key is Iterable);
    return sembast.Finder(filter: storeKeyFilter(keyPath, key));
  }

  Future<Object?> txnCompositeFindIdByKey(Object key) async {
    var existing = await sembastStore.findKey(
      sembastClient,
      finder: compositeFindByKeyFinder(key),
    );
    return existing;
  }

  bool get hasCompositeKey => keyPath is Iterable;

  @override
  Future<Object> add(Object value, [Object? key]) {
    value = toSembastValue(value);
    return _inWritableTransaction(() async {
      var fixedKey = getKeyImpl(value, key);

      if (fixedKey != null) {
        var existingValue = await txnGetSnapshot(fixedKey);
        if (existingValue != null) {
          throw DatabaseError('Key $key already exists in the object store');
        }
        return putImpl(value, fixedKey);
      } else {
        return putImpl(value, null);
      }
    });
  }

  @override
  Future clear() {
    return _inWritableTransaction(() {
      return sembastStore.delete(sembastClient);
    }).then((_) {
      return null;
    });
  }

  sembast.Filter _storeKeyOrRangeFilter([Object? keyOrRange]) {
    return keyOrRangeFilter(sembast.Field.key, keyOrRange, false);
  }

  @override
  Future<int> count([keyOrRange]) {
    return inTransaction(() {
      return sembastStore.count(
        sembastClient,
        filter: _storeKeyOrRangeFilter(keyOrRange),
      );
    });
  }

  @override
  Future<List<Object>> getAll([Object? query, int? count]) {
    return inTransaction(() async {
      return (await txnGetAllSnapshots(
        query,
        count,
      )).map((r) => recordToValue(r)!).toList(growable: false);
    });
  }

  Future<List<sembast.RecordSnapshot<Object, Object>>> txnGetAllSnapshots([
    Object? query,
    int? count,
  ]) async {
    return (await sembastStore.find(
      sembastClient,
      finder: sembast.Finder(
        filter: _storeKeyOrRangeFilter(query),
        limit: count,
      ),
    ));
  }

  Future<sembast.RecordSnapshot<Object, Object>?> txnCompositeGetSnapshot(
    Object key,
  ) async {
    return (await sembastStore.findFirst(
      sembastClient,
      finder: compositeFindByKeyFinder(key),
    ));
  }

  /// Ids are key for non composite key
  Future<List<Object>> txnGetAllIds([Object? query, int? count]) async {
    return (await sembastStore.findKeys(
      sembastClient,
      finder: sembast.Finder(
        filter: _storeKeyOrRangeFilter(query),
        limit: count,
      ),
    ));
  }

  @override
  Future<List<Object>> getAllKeys([Object? query, int? count]) {
    return inTransaction(() async {
      if (hasCompositeKey) {
        var keys = (await txnGetAllSnapshots(
          query,
          count,
        )).map((r) => (r as Map).getKeyValue(keyPath)!).toList(growable: false);
        return keys;
      }
      return await txnGetAllIds(query, count);
    });
  }

  @override
  Index createIndex(String name, keyPath, {bool? unique, bool? multiEntry}) {
    // Be compatible with Chrome
    if (keyPath is List) {
      // // Native: InvalidAccessError: Failed to execute 'createIndex' on 'IDBObjectStore': The keyPath argument was an array and the multiEntry option is true.
      if (multiEntry ?? false) {
        throw DatabaseError(
          'The keyPath argument $keyPath cannot be an array if the multiEntry option is true',
        );
      }
    }
    final indexMeta = IdbIndexMeta(name, keyPath, unique, multiEntry);
    meta!.createIndex(database.meta, indexMeta);
    return IndexSembast(this, indexMeta);
  }

  @override
  void deleteIndex(String name) {
    meta!.deleteIndex(database.meta, name);
  }

  @override
  Future<Object?> delete(Object keyOrRange) {
    return _inWritableTransaction(() {
      return txnDelete(keyOrRange);
    });
  }

  Future<Object?> txnDelete(Object keyOrRange) {
    if (keyOrRange is KeyRange) {
      return sembastStore.delete(
        sembastClient,
        finder: sembast.Finder(
          filter: keyRangeFilter(keyPath, keyOrRange, false),
        ),
      );
    } else if (hasCompositeKey) {
      return sembastStore.delete(
        sembastClient,
        finder: compositeFindByKeyFinder(keyOrRange),
      );
    } else {
      return sembastStore.record(keyOrRange).delete(sembastClient);
    }
  }

  /// Clone and convert
  Object? recordToValue(sembast.RecordSnapshot<Object, Object>? record) {
    if (record == null) {
      return null;
    } else {
      var value = record.value;
      return fromSembastValue(value);
    }
  }

  Future<sembast.RecordSnapshot<Object, Object>?> txnGetSnapshot(
    Object key,
  ) async {
    sembast.RecordSnapshot<Object, Object>? record;
    if (hasCompositeKey) {
      record = await txnCompositeGetSnapshot(key);
    } else {
      record = await sembastStore.record(key).getSnapshot(sembastClient);
    }

    return record;
  }

  @override
  Future<Object?> getObject(Object key) {
    checkKeyParam(key);
    return inTransaction(() async {
      var record = await txnGetSnapshot(key);
      return recordToValue(record);
    });
  }

  @override
  Index index(String name) {
    final indexMeta = meta!.index(name);
    return IndexSembast(this, indexMeta);
  }

  /// Get the sembast sort orders.
  List<sembast.SortOrder> sortOrders(bool ascending) =>
      keyPathSortOrders(keyField, ascending);

  /// Convert to a sembast filter.
  sembast.Filter cursorFilter(Object? key, KeyRange? range) {
    if (range != null) {
      return keyRangeFilter(keyField, range, false);
    } else {
      return keyFilter(keyField, key, false);
    }
  }

  /// Get the keyPath or default sembast key
  dynamic get keyField => keyPath ?? sembast.Field.key;

  @override
  Stream<CursorWithValue> openCursor({
    key,
    KeyRange? range,
    String? direction,
    bool? autoAdvance,
  }) {
    final cursorMeta = IdbCursorMeta(key, range, direction, autoAdvance);
    final ctlr = StoreCursorWithValueControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Stream<Cursor> openKeyCursor({
    key,
    KeyRange? range,
    String? direction,
    bool? autoAdvance,
  }) {
    final cursorMeta = IdbCursorMeta(key, range, direction, autoAdvance);
    var ctlr = StoreKeyCursorControllerSembast(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Future<Object> put(Object value, [Object? key]) {
    return _inWritableTransaction(() {
      return txnPut(value, key);
    });
  }

  /// Assume in transaction.
  Future<Object> txnPut(Object value, [Object? key]) {
    value = toSembastValue(value);
    var fixedKey = getKeyImpl(value, key);
    return putImpl(value, fixedKey);
  }
}
