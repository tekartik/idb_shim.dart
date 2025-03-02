import 'package:idb_shim/src/sdb/sdb_boundary_impl.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_impl.dart';
import 'package:idb_shim/src/utils/idb_utils.dart';
import 'package:idb_shim/utils/idb_utils.dart' as idb;

import 'sdb_boundary.dart';
import 'sdb_filter.dart';
import 'sdb_filter_impl.dart';
import 'sdb_key_utils.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_record_snapshot_impl.dart';
import 'sdb_store.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction_store.dart';
import 'sdb_types.dart';

/// SimpleDb transaction internal extension.
extension SdbSingleStoreTransactionInternalExtension<
  K extends KeyBase,
  V extends ValueBase
>
    on SdbSingleStoreTransaction<K, V> {
  /// Single store transaction implementation.
  SdbSingleStoreTransactionImpl<K, V> get impl =>
      this as SdbSingleStoreTransactionImpl<K, V>;
}

/// SimpleDb single store transaction implementation.
class SdbSingleStoreTransactionImpl<K extends KeyBase, V extends ValueBase>
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

  /// Add a record.
  Future<K> addImpl(V value) => txnStore.add(value);

  /// run in a transaction.
  Future<T> run<T>(
    Future<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) async {
    var result = callback(this);
    await completed;
    return result;
  }

  /// Put a record.
  Future<void> putImpl(K key, V value) => txnStore.put(key, value);

  /// Delete a record.
  Future<void> deleteImpl(K key) => txnStore.delete(key);

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl({
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    required SdbFilter? filter,
    int? offset,
    int? limit,
  }) => txnStore.findRecords(
    boundaries: boundaries,
    filter: filter,
    offset: offset,
    limit: limit,
  );

  /// Find records.
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl({
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
  }) => txnStore.findRecordKeys(
    boundaries: boundaries,
    offset: offset,
    limit: limit,
  );
}

/// Transaction store reference internal extension.
extension SdbTransactionStoreRefInternalExtension<
  K extends KeyBase,
  V extends ValueBase
>
    on SdbTransactionStoreRef<K, V> {
  /// Transaction store reference implementation.
  SdbTransactionStoreRefImpl<K, V> get impl =>
      this as SdbTransactionStoreRefImpl<K, V>;
}

/// Transaction store reference implementation.
class SdbTransactionStoreRefImpl<K extends KeyBase, V extends ValueBase>
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

  /// Add a record.
  Future<K> addImpl(V value) async {
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

  /// Put a record.
  Future<void> putImpl(K? key, V value) async {
    await idbObjectStore.put(value, key);
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

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl({
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    required SdbFilter? filter,
    int? offset,
    int? limit,
  }) async {
    var cursor = idbObjectStore.openCursor(
      autoAdvance: true,
      direction: idb.idbDirectionNext,
      range: idbKeyRangeFromBoundaries(boundaries),
    );
    if (filter == null) {
      var rows = await idb.cursorToList(cursor, offset, limit);
      return rows.map(_sdbRecordSnapshot).toList();
    } else {
      /// Non optimized
      var rows = await idb.cursorToList(cursor);
      rows.applyFilterOffsetAndLimit(filter, limit: limit, offset: offset);
      return rows.map(_sdbRecordSnapshot).toList();
    }
  }

  SdbRecordKey<K, V> _sdbRecordKey(idb.KeyCursorRow row) {
    var key = row.key as K;
    return SdbRecordKeyImpl<K, V>(store, key);
  }

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl({
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
  }) async {
    var cursor = idbObjectStore.openKeyCursor(
      autoAdvance: true,
      direction: idb.idbDirectionNext,
      range: idbKeyRangeFromBoundaries(boundaries),
    );
    var rows = await idb.keyCursorToList(cursor, offset, limit);
    return rows.map(_sdbRecordKey).toList();
  }

  /// Count records.
  Future<int> countImpl({SdbBoundaries<K>? boundaries}) async {
    return idbObjectStore.count(idbKeyRangeFromBoundaries(boundaries));
  }

  /// Delete records.
  Future<void> deleteRecordsImpl({
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
  }) async {
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
        direction: idb.idbDirectionNext,
        range: keyRange,
      );
      await streamWithOffsetAndLimit(cursor, offset, limit).listen((cursor) {
        cursor.delete();
      }).asFuture<void>();
    }
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
  SdbTransactionStoreRef<K, V> txnStoreImpl<
    K extends KeyBase,
    V extends ValueBase
  >(SdbStoreRef<K, V> store) {
    var txnStore = _txnStoreMap[store];
    if (txnStore == null) {
      for (var existingStore in stores) {
        if (existingStore == store) {
          txnStore =
              _txnStoreMap[store] = SdbTransactionStoreRefImpl<K, V>(
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
    Future<T> Function(SdbMultiStoreTransaction txn) callback,
  ) async {
    var result = callback(this);
    await completed;
    return result;
  }
}
