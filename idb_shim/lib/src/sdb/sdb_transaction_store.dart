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

  /// Stream records.
  Stream<SdbRecordSnapshot<K, V>> streamRecords({SdbFindOptions<K>? options}) {
    return _impl.streamRecordsImpl(options: sdbFindOptionsMerge(options));
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecords({
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional sort order
    bool? descending,

    /// New API, supercedes the other parameters
    SdbFindOptions<K>? options,
  }) {
    options = sdbFindOptionsMerge(
      options,
      boundaries: boundaries,
      limit: limit,
      offset: offset,
      descending: descending,
      filter: filter,
    );
    return _impl.findRecordsImpl(options: options);
  }

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeys({
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional descending order
    bool? descending,

    /// New API, supercedes the other parameters
    SdbFindOptions<K>? options,
  }) {
    options = sdbFindOptionsMerge(
      boundaries: boundaries,
      options,
      limit: limit,
      offset: offset,
      descending: descending,
      filter: filter,
    );
    return _impl.findRecordKeysImpl(options: options);
  }

  /// Count record.
  Future<int> count({
    SdbBoundaries<K>? boundaries,
    SdbFindOptions<K>? options,
  }) => _impl.countImpl(
    options: sdbFindOptionsMerge(options, boundaries: boundaries),
  );

  /// Delete records.
  Future<void> deleteRecords({
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,

    /// Optional descending order
    bool? descending,

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) => _impl.deleteRecordsImpl(
    options: sdbFindOptionsMerge(
      options,
      boundaries: boundaries,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
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

    /// New API, supercedes the other parameters
    SdbFindOptions<K>? options,
  }) => impl.findRecordsImpl(
    options: sdbFindOptionsMerge(
      options,
      boundaries: boundaries,
      filter: filter,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
  );

  /// Find records.
  Stream<SdbRecordSnapshot<K, V>> streamRecords({SdbFindOptions<K>? options}) =>
      impl.streamRecordsImpl(options: sdbFindOptionsMerge(options));

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeys({
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,
    bool? descending,

    /// New API, supercedes the other parameters
    SdbFindOptions<K>? options,
  }) => impl.findRecordKeysImpl(
    options: sdbFindOptionsMerge(
      options,
      boundaries: boundaries,
      filter: filter,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
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
