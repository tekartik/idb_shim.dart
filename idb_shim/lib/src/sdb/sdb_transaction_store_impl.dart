import 'dart:async';
import 'dart:math';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_boundary_impl.dart';
import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_impl.dart';
import 'package:idb_shim/src/sdb/sdb_utils.dart';
import 'package:idb_shim/src/utils/cursor_utils.dart';
import 'package:idb_shim/src/utils/idb_utils.dart';
import 'package:idb_shim/utils/idb_utils.dart' as idb;

import 'sdb_filter_impl.dart';
import 'sdb_key_utils.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_record_snapshot_impl.dart';
import 'sdb_store_impl.dart';

/// SimpleDb transaction internal extension.
extension SdbSingleStoreTransactionInternalExtension<
  K extends SdbKey,
  V extends SdbValue
>
    on SdbSingleStoreTransaction<K, V> {
  /// Single store transaction implementation.
  SdbSingleStoreTransactionImpl<K, V> get impl =>
      this as SdbSingleStoreTransactionImpl<K, V>;
}

/// SimpleDb single store transaction implementation.
class SdbSingleStoreTransactionImpl<K extends SdbKey, V extends SdbValue>
    extends SdbTransactionImpl
    implements SdbSingleStoreTransaction<K, V> {
  @override
  final SdbTransactionStoreRefImpl<K, V> txnStore;

  /// Single store transaction implementation.
  SdbSingleStoreTransactionImpl(super.db, super.mode, this.txnStore) {
    txnStore.transaction = this;
    idbTransaction = db.idbDatabase.transaction(
      txnStore.name,
      idbTransactionMode(mode),
    );
  }

  /// Get a single record.
  Future<SdbRecordSnapshotImpl<K, V>?> getRecordImpl(K key) =>
      txnStore.getRecordImpl(key);

  /// Check if a record exists.
  Future<bool> existsImpl(K key) async {
    var record = await getRecordImpl(key);
    return record != null;
  }

  /// Add a record.
  Future<K> addImpl(V value) => txnStore.add(value);

  /// run in a transaction.
  Future<T> run<T>(
    FutureOr<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) async {
    return runCallback(() => callback(this));
  }

  /// Put a record.
  Future<void> putImpl(K key, V value) => txnStore.put(key, value);

  /// Delete a record.
  Future<void> deleteImpl(K key) => txnStore.delete(key);

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl({
    required SdbFindOptions<K> options,
  }) => txnStore.findRecords(options: options);

  /// Stream records.
  Stream<SdbRecordSnapshot<K, V>> streamRecordsImpl({
    required SdbFindOptions<K> options,
  }) => txnStore.streamRecords(options: options);

  /// Find records.
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl({
    required SdbFindOptions<K> options,
  }) => txnStore.findRecordKeys(options: options);
}

/// Transaction store reference internal extension.
extension SdbTransactionStoreRefInternalExtension<
  K extends SdbKey,
  V extends SdbValue
>
    on SdbTransactionStoreRef<K, V> {
  /// Transaction store reference implementation.
  SdbTransactionStoreRefImpl<K, V> get impl =>
      this as SdbTransactionStoreRefImpl<K, V>;
}

/// Transaction store reference implementation mixin.
mixin SdbTransactionStoreRefImplMixin<K extends SdbKey, V extends SdbValue>
    implements SdbTransactionStoreRef<K, V> {
  /// idb object store.
  idb.ObjectStore get idbObjectStore;

  /// Put a record.
  Future<void> putImpl(K? key, V value) async {
    await idbObjectStore.put(value, key);
  }

  @override
  SdbKeyPath? get keyPath =>
      idbKeyPathToSdbKeyPathOrNull(idbObjectStore.keyPath);

  @override
  Iterable<String> get indexNames => idbObjectStore.indexNames;
}

/// Transaction store reference implementation.
class SdbTransactionStoreRefImpl<K extends SdbKey, V extends SdbValue>
    with SdbTransactionStoreRefImplMixin<K, V>
    implements SdbTransactionStoreRef<K, V> {
  // Set later
  @override
  late SdbTransactionImpl transaction;
  @override
  final SdbStoreRefImpl<K, V> store;

  /// Transaction reference implementation.
  SdbTransactionStoreRefImpl.txn(this.transaction, this.store);

  /// Transaction reference implementation.
  SdbTransactionStoreRefImpl(this.store);

  idb.ObjectStore? _idbObjectStore;

  /// idb object store.
  @override
  idb.ObjectStore get idbObjectStore =>
      _idbObjectStore ??= transaction.idbTransaction.objectStore(store.name);

  /// Get a single record.
  Future<SdbRecordSnapshotImpl<K, V>?> getRecordImpl(K key) async {
    var result = await idbObjectStore.getObject(key);
    if (result != null) {
      // cast the map if needed
      if (result is Map && store is! SdbModel) {
        result = result.cast<String, Object?>();
      }
      return SdbRecordSnapshotImpl<K, V>(store, key, fixResult<V>(result));
    }
    return null;
  }

  /// Check if a record exists.
  Future<bool> existsImpl(K key) async {
    var value = await getRecordImpl(key);
    return value != null;
  }

  /// Add a record.
  Future<K> addImpl(V value) async {
    if (idbObjectStore.keyPath != null) {
      return (await idbObjectStore.add(value)) as K;
    }
    if (K == int) {
      return (await idbObjectStore.add(value)) as K;
    } else if (K == String) {
      String key;
      while (true) {
        key = generateStringKey();
        if (await idbObjectStore.getObject(key) == null) {
          break;
        }
      }
      return (await idbObjectStore.add(value, key)) as K;
    } else {
      throw UnsupportedError(
        'Key type $K not supported for add, please specify a key',
      );
    }
  }

  /// Delete a record.
  Future<void> deleteImpl(K key) async {
    await idbObjectStore.delete(key);
  }

  SdbRecordSnapshotImpl<K, V> _sdbRecordSnapshot(idb.CursorRow row) {
    var key = row.primaryKey as K;
    var value = row.value as V;
    return SdbRecordSnapshotImpl<K, V>(store, key, value);
  }

  /// Stream records
  Stream<SdbRecordSnapshot<K, V>> streamRecordsImpl({
    required SdbFindOptions<K> options,
  }) {
    var filter = options.filter;
    var offset = options.offset;
    var limit = options.limit;
    var descending = options.descending;
    var boundaries = options.boundaries;
    var cursor = idbObjectStore.openCursor(
      direction: descendingToIdbDirection(descending),
      range: idbKeyRangeFromBoundaries(boundaries),
    );

    return cursor
        .limitOffsetStream(
          offset: offset,
          limit: limit,
          matcher: filter != null
              ? (cwv) => sdbCursorWithValueMatchesFilter(cwv, filter)
              : null,
        )
        .map(_sdbRecordSnapshot);
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl({
    required SdbFindOptions<K> options,
  }) async {
    var filter = options.filter;
    var offset = options.offset;
    var limit = options.limit;
    var descending = options.descending;
    var boundaries = options.boundaries;
    var cursor = idbObjectStore.openCursor(
      direction: descendingToIdbDirection(descending),
      range: idbKeyRangeFromBoundaries(boundaries),
    );

    var rows = await cursor.toRowList(
      offset: offset,
      limit: limit,
      matcher: filter != null
          ? (cwv) => sdbCursorWithValueMatchesFilter(cwv, filter)
          : null,
    );
    return rows.map(_sdbRecordSnapshot).toList();
  }

  SdbRecordKey<K, V> _sdbRecordKey(idb.KeyCursorRow row) {
    var key = row.key as K;
    return SdbRecordKeyImpl<K, V>(store, key);
  }

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl({
    required SdbFindOptions<K> options,
  }) async {
    if (options.filter != null) {
      return findRecordsImpl(options: options);
    }
    var descending = options.descending;
    var offset = options.offset;
    var limit = options.limit;
    var boundaries = options.boundaries;
    var cursor = idbObjectStore.openKeyCursor(
      autoAdvance: true,
      direction: descendingToIdbDirection(descending),
      range: idbKeyRangeFromBoundaries(boundaries),
    );
    var rows = await idb.keyCursorToList(cursor, offset, limit);
    return rows.map(_sdbRecordKey).toList();
  }

  /// Count records.
  Future<int> countImpl({required SdbFindOptions<K> options}) async {
    if (options.filter != null) {
      // Slow
      return (await findRecordsImpl(options: options)).length;
    }
    var boundaries = options.boundaries;
    var count = await idbObjectStore.count(
      idbKeyRangeFromBoundaries(boundaries),
    );
    var offset = options.offset;
    var limit = options.limit;
    if ((offset ?? -1) > 0) {
      count = max(0, count - offset!);
    }
    if ((limit ?? -1) > 0) {
      count = max(count, limit!);
    }
    return count;
  }

  /// Delete records.
  Future<void> deleteRecordsImpl({required SdbFindOptions<K> options}) async {
    if (options.filter != null) {
      // Slow
      var records = await findRecordsImpl(options: options);
      for (var record in records) {
        await deleteImpl(record.key);
      }
      return;
    }
    var boundaries = options.boundaries;

    var offset = options.offset;
    var limit = options.limit;
    var descending = options.descending;
    var keyRange = idbKeyRangeFromBoundaries(boundaries);

    if (offset == null && limit == null) {
      if (keyRange == null) {
        await idbObjectStore.clear();
      } else {
        await idbObjectStore.delete(keyRange);
      }
    } else {
      var cursor = idbObjectStore.openCursor(
        autoAdvance: true,
        direction: descendingToIdbDirection(descending),
        range: keyRange,
      );
      await streamWithOffsetAndLimit(cursor, offset, limit).listen((cursor) {
        cursor.delete();
      }).asFuture<void>();
    }
  }

  @override
  SdbTransactionIndexRef<K, V, I> index<I extends SdbIndexKey>(
    SdbIndexRef<K, V, I> ref,
  ) {
    return SdbTransactionIndexRef<K, V, I>(index: ref, txnStore: this);
  }
}

/// Multi store transaction internal extension.
extension SdbMultiStoreTransactionInternalExtension
    on SdbMultiStoreTransaction {
  /// Multi store transaction implementation.
  SdbMultiStoreTransactionImpl get impl => this as SdbMultiStoreTransactionImpl;
}

/// Multi store transaction implementation.
class SdbMultiStoreTransactionImpl extends SdbTransactionImpl
    implements SdbMultiStoreTransaction {
  /// Stores.
  List<SdbStoreRef> stores;

  /// Filled when requested.
  final _txnStoreMap = <SdbStoreRef, SdbTransactionStoreRefImpl>{};

  /// Multi store transaction implementation.
  SdbMultiStoreTransactionImpl(super.db, super.mode, this.stores) {
    idbTransaction = db.idbDatabase.transactionList(
      stores.map((store) => store.name).toList(),
      idbTransactionMode(mode),
    );
  }

  /// Get a transaction store.
  SdbTransactionStoreRef<K, V>
  txnStoreImpl<K extends SdbKey, V extends SdbValue>(SdbStoreRef<K, V> store) {
    var txnStore = _txnStoreMap[store];
    if (txnStore == null) {
      for (var existingStore in stores) {
        if (existingStore == store) {
          txnStore = _txnStoreMap[store] = SdbTransactionStoreRefImpl<K, V>(
            store.impl,
          );
          txnStore.transaction = this;
          break;
        }
      }
    }
    if (txnStore != null) {
      return txnStore as SdbTransactionStoreRef<K, V>;
    }
    throw StateError(
      'Store $store not found in transaction(${stores.map((e) => e.name).join(', ')})',
    );
  }

  /// Run in a transaction.
  Future<T> run<T>(
    FutureOr<T> Function(SdbMultiStoreTransaction txn) callback,
  ) async {
    return runCallback(() => callback(this));
  }
}
