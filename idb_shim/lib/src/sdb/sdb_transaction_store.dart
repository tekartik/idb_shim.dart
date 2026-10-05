import 'package:idb_shim/sdb.dart';

/// Transaction store reference.
abstract class SdbTransactionStoreRef<K extends SdbKey, V extends SdbValue> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Transaction reference.
  SdbTransaction get transaction;

  /// Key Path.
  SdbKeyPath? get keyPath;

  /// Auto increment
  bool get autoIncrement;

  /// Index names.
  Iterable<String> get indexNames;

  /// Get a transaction index.
  SdbTransactionIndexRef<K, V, I> index<I extends SdbIndexKey>(
    SdbIndexRef<K, V, I> ref,
  );
}

/// Internal interface implemented by every transaction store, idb based or
/// not. The public [SdbTransactionStoreRefExtension] goes through it.
abstract class SdbTransactionStoreRefInterface<
  K extends SdbKey,
  V extends SdbValue
>
    implements SdbTransactionStoreRef<K, V> {
  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> getRecordImpl(K key);

  /// True if the record exists.
  Future<bool> existsImpl(K key);

  /// Add a record, the key is generated.
  Future<K> addImpl(V value);

  /// Put a record, [key] is null for inline keys (keyPath).
  Future<void> putImpl(K? key, V value);

  /// Put an already encoded (raw) value at [key], as read by a cursor row,
  /// for import and migration. The change listeners are not told about it.
  Future<void> putRawImpl(K key, Object rawValue);

  /// Delete a record.
  Future<void> deleteImpl(K key);

  /// Stream records.
  Stream<SdbRecordSnapshot<K, V>> streamRecordsImpl({
    required SdbFindOptions<K> options,
  });

  /// Iterate on records, the handler returns false to stop.
  Future<void> iterateImpl({
    required SdbFindOptions<K> options,
    required SdbCursorRowHandler<K, V> handler,
  });

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl({
    required SdbFindOptions<K> options,
  });

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl({
    required SdbFindOptions<K> options,
  });

  /// Count records.
  Future<int> countImpl({required SdbFindOptions<K> options});

  /// Delete records.
  Future<void> deleteRecordsImpl({required SdbFindOptions<K> options});
}

/// Transaction store actions.
extension SdbTransactionStoreRefExtension<K extends SdbKey, V extends SdbValue>
    on SdbTransactionStoreRef<K, V> {
  SdbTransactionStoreRefInterface<K, V> get _impl =>
      this as SdbTransactionStoreRefInterface<K, V>;

  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> getRecord(K key) => _impl.getRecordImpl(key);

  /// Get a single value.
  Future<V?> getValue(K key) =>
      getRecord(key).then((snapshot) => snapshot?.value);

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
  Future<SdbRecordSnapshot<K, V>?> getRecord(K key) => txnStore.getRecord(key);

  /// Add a record
  Future<K> add(V value) => txnStore.add(value);

  /// Put a record
  Future<void> put(K key, V value) => txnStore.put(key, value);

  /// Delete a record
  Future<void> delete(K key) => txnStore.delete(key);

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
  }) => txnStore.findRecords(
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
      txnStore.streamRecords(options: sdbFindOptionsMerge(options));

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
  }) => txnStore.findRecordKeys(
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
  @Deprecated('Use txn.store(store) instead')
  SdbTransactionStoreRef<K, V> txnStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
  ) => this.store<K, V>(store);
}
