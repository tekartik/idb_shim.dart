import 'package:idb_shim/sdb.dart';

import 'sdb_transaction_store_impl.dart';

/// Transaction store reference.
abstract class SdbTransactionStoreRef<K extends SdbKey, V extends SdbValue> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Transaction reference.
  SdbTransaction get transaction;

  /// Key Path.
  SdbKeyPath? get keyPath;

  /// Index names.
  Iterable<String> get indexNames;

  /// Get a transaction index.
  SdbTransactionIndexRef<K, V, I> index<I extends SdbIndexKey>(
    SdbIndexRef<K, V, I> ref,
  );
}

/// Transaction store actions.
extension SdbTransactionStoreRefExtension<K extends SdbKey, V extends SdbValue>
    on SdbTransactionStoreRef<K, V> {
  SdbTransactionStoreRefImpl<K, V> get _impl =>
      this as SdbTransactionStoreRefImpl<K, V>;

  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> getRecord(K key) => _impl.getRecordImpl(key);

  /// True if the record exists.
  Future<bool> exists(K key) => _impl.existsImpl(key);

  /// Add.
  Future<K> add(V value) => _impl.addImpl(value);

  /// Put.
  Future<void> put(K? key, V value) => _impl.putImpl(key, value);

  /// Delete.
  Future<void> delete(K key) => _impl.deleteImpl(key);

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecords({
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional sort order
    bool? descending,
  }) => _impl.findRecordsImpl(
    boundaries: boundaries,
    filter: filter,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeys({
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,

    /// Optional descending order
    bool? descending,
  }) => _impl.findRecordKeysImpl(
    boundaries: boundaries,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// Count record.
  Future<int> count({SdbBoundaries<K>? boundaries}) =>
      _impl.countImpl(boundaries: boundaries);

  /// Delete records.
  Future<void> deleteRecords({
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,

    /// Optional descending order
    bool? descending,
  }) => _impl.deleteRecordsImpl(
    boundaries: boundaries,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// store name.
  String get name => store.name;

  /// Key Path.
  Object? get keyPath => _impl.idbObjectStore.keyPath;

  /// Auto increment.
  bool get autoIncrement => _impl.idbObjectStore.autoIncrement;
}

/// Single store transaction.
abstract class SdbSingleStoreTransaction<K extends SdbKey, V extends SdbValue>
    implements SdbTransaction {
  /// Transaction store reference.
  SdbTransactionStoreRef<K, V> get txnStore;
}

/// Single store transaction extension.
extension SdbSingleStoreTransactionExtension<
  K extends SdbKey,
  V extends SdbValue
>
    on SdbSingleStoreTransaction<K, V> {
  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> getRecord(K key) => impl.getRecordImpl(key);

  /// Add a record
  Future<K> add(V value) => impl.addImpl(value);

  /// Put a record
  Future<void> put(K key, V value) => impl.putImpl(key, value);

  /// Delete a record
  Future<void> delete(K key) => impl.deleteImpl(key);

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecords({
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional descending sort order
    bool? descending,
  }) => impl.findRecordsImpl(
    boundaries: boundaries,
    filter: filter,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeys({
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) => impl.findRecordKeysImpl(
    boundaries: boundaries,
    offset: offset,
    limit: limit,
    descending: descending,
  );
}

/// Multi-store transaction.
abstract class SdbMultiStoreTransaction implements SdbTransaction {}

/// Transaction store actions.
extension SdbMultiStoreTransactionExtension on SdbMultiStoreTransaction {
  /// Get a transaction store.
  SdbTransactionStoreRef<K, V> txnStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
  ) => impl.txnStoreImpl<K, V>(store);
}
