import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/sdb/sdb_index_impl.dart';
import 'package:idb_shim/src/sdb/sdb_record_impl.dart';

import 'sdb_client.dart';
import 'sdb_database_impl.dart';
import 'sdb_transaction_impl.dart';
import 'sdb_types.dart';

/// Store reference internal extension.
extension SdbStoreRefInternalExtension<K extends KeyBase, V extends ValueBase>
    on SdbStoreRef<K, V> {
  /// Store reference implementation.
  SdbStoreRefImpl<K, V> get impl => this as SdbStoreRefImpl<K, V>;
}

/// Store reference implementation.
class SdbStoreRefImpl<K extends KeyBase, V extends ValueBase>
    implements SdbStoreRef<K, V> {
  @override
  final String name;

  /// Store reference implementation.
  SdbStoreRefImpl(this.name) {
    if (!(K == int || K == String)) {
      throw ArgumentError('K type $K must be int or String');
    }
  }

  /// Add a single record.
  @override
  Future<K> add(SdbClient client, V value) =>
      client.interface.sdbAddImpl<K, V>(this, value);

  /// Put a single record (when using inline keys)
  @override
  Future<K> put(SdbClient client, V value) => impl.putImpl(client, value);

  /// Find records.
  @override
  Future<List<SdbRecordSnapshot<K, V>>> findRecords(
    SdbClient client, {

    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional sort order
    bool? descending,
  }) => impl.findRecordsImpl(
    client,
    boundaries: boundaries,
    filter: filter,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// Find records.
  @override
  Future<List<SdbRecordKey<K, V>>> findRecordKeys(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) => impl.findRecordKeysImpl(
    client,
    boundaries: boundaries,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// Count records.
  @override
  Future<int> count(SdbClient client, {SdbBoundaries<K>? boundaries}) =>
      impl.countImpl(client, boundaries: boundaries);

  /// Delete records.
  @override
  Future<void> delete(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) => impl.deleteImpl(
    client,
    boundaries: boundaries,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// Record reference.
  @override
  SdbRecordRef<K, V> record(K key) => SdbRecordRefImpl<K, V>(impl, key);

  /// Index reference on 1 field
  @override
  SdbIndex1Ref<K, V, I> index<I extends IndexBase>(String name) =>
      SdbIndex1RefImpl<K, V, I>(impl, name);

  /// Index reference on 2 fields
  @override
  SdbIndex2Ref<K, V, I1, I2> index2<I1 extends IndexBase, I2 extends IndexBase>(
    String name,
  ) => SdbIndex2RefImpl<K, V, I1, I2>(impl, name);

  /// Index reference on 3 fields
  @override
  SdbIndex3Ref<K, V, I1, I2, I3> index3<
    I1 extends IndexBase,
    I2 extends IndexBase,
    I3 extends IndexBase
  >(String name) => SdbIndex3RefImpl<K, V, I1, I2, I3>(impl, name);

  /// Index reference on 4 fields
  @override
  SdbIndex4Ref<K, V, I1, I2, I3, I4> index4<
    I1 extends IndexBase,
    I2 extends IndexBase,
    I3 extends IndexBase,
    I4 extends IndexBase
  >(String name) => SdbIndex4RefImpl<K, V, I1, I2, I3, I4>(impl, name);

  /// Lower boundary
  @override
  SdbBoundary<K> lowerBoundary(K value, {bool? include = true}) =>
      SdbLowerBoundary(value, include: include);

  /// Upper boundary
  @override
  SdbBoundary<K> upperBoundary(K value, {bool? include = false}) =>
      SdbUpperBoundary(value, include: include);

  /// True if the key is an int.
  bool get isIntKey => K == int;

  @override
  String toString() => 'Store($name)';

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is SdbStoreRef) {
      return name == other.name;
    }
    return false;
  }

  /// Add a single record.
  Future<K> addImpl(SdbClient client, V value) => client.handleDbOrTxn(
    (db) => dbAddImpl(db, value),
    (txn) => txnAddImpl(txn.rawImpl, value),
  );

  /// Add a single record.
  Future<K> dbAddImpl(SdbDatabaseImpl db, V value) {
    return db.inStoreTransaction<K, K, V>(this, SdbTransactionMode.readWrite, (
      txn,
    ) {
      return txn.add(value);
    });
  }

  /// Add a single record.
  Future<K> txnAddImpl(SdbTransactionImpl txn, V value) {
    return txn.storeImpl(this).add(value);
  }

  /// Put a single record (inline keys)
  Future<K> putImpl(SdbClient client, V value) => client.handleDbOrTxn(
    (db) => dbPutImpl(db, value),
    (txn) => txnPutImpl(txn.rawImpl, value),
  );

  /// Put a single record (inline keys)
  Future<K> dbPutImpl(SdbDatabaseImpl db, V value) {
    return db.inStoreTransaction<K, K, V>(this, SdbTransactionMode.readWrite, (
      txn,
    ) {
      return txnPutImpl(txn.rawImpl, value);
    });
  }

  /// Put a single record (inline keys)
  Future<K> txnPutImpl(SdbTransactionImpl txn, V value) {
    return txn.storeImpl(this).put(null, value).then((_) {
      var keyPath = txn.storeImpl(this).idbObjectStore.keyPath;
      // Get the key from the value
      return mapValueAtKeyPath(value as Map, keyPath) as K;
    });
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional sort order
    bool? descending,
  }) => client.handleDbOrTxn(
    (db) => dbFindRecordsImpl(
      db,
      boundaries: boundaries,
      filter: filter,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
    (txn) => txnFindRecordsImpl(
      txn,
      boundaries: boundaries,
      filter: filter,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
  );

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> dbFindRecordsImpl(
    SdbDatabase db, {
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional sort order
    bool? descending,
  }) {
    return db.inStoreTransaction(this, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordsImpl(
        txn.rawImpl,
        boundaries: boundaries,
        filter: filter,
        offset: offset,
        limit: limit,
        descending: descending,
      );
    });
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> txnFindRecordsImpl(
    SdbTransactionImpl txn, {
    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional sort order
    bool? descending,
  }) {
    return txn
        .storeImpl(this)
        .findRecords(
          boundaries: boundaries,
          filter: filter,
          offset: offset,
          limit: limit,
          descending: descending,
        );
  }

  /// Find records keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,

    /// Optional descending order
    bool? descending,
  }) => client.handleDbOrTxn(
    (db) => dbFindRecordKeysImpl(
      db,
      boundaries: boundaries,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
    (txn) => txnFindRecordKeysImpl(
      txn,
      boundaries: boundaries,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
  );

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> dbFindRecordKeysImpl(
    SdbDatabase db, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,

    /// Optional descending order
    bool? descending,
  }) {
    return db.inStoreTransaction(this, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordKeysImpl(
        txn.rawImpl,
        boundaries: boundaries,
        offset: offset,
        limit: limit,
        descending: descending,
      );
    });
  }

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> txnFindRecordKeysImpl(
    SdbTransactionImpl txn, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) {
    return txn
        .storeImpl(this)
        .findRecordKeys(
          boundaries: boundaries,
          offset: offset,
          limit: limit,
          descending: descending,
        );
  }

  /// Count records.
  Future<int> countImpl(SdbClient client, {SdbBoundaries<K>? boundaries}) =>
      client.handleDbOrTxn(
        (db) => dbCountImpl(db, boundaries: boundaries),
        (txn) => txnCountImpl(txn, boundaries: boundaries),
      );

  /// Count records.
  Future<int> dbCountImpl(SdbDatabase db, {SdbBoundaries<K>? boundaries}) {
    return db.inStoreTransaction(this, SdbTransactionMode.readOnly, (txn) {
      return txnCountImpl(txn.rawImpl, boundaries: boundaries);
    });
  }

  /// Count records.
  Future<int> txnCountImpl(
    SdbTransactionImpl txn, {
    SdbBoundaries<K>? boundaries,
  }) {
    return txn.storeImpl(this).count(boundaries: boundaries);
  }

  /// Delete records.
  Future<void> deleteImpl(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) => client.handleDbOrTxn(
    (db) => dbDeleteImpl(
      db,
      boundaries: boundaries,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
    (txn) => txnDeleteImpl(
      txn,
      boundaries: boundaries,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
  );

  /// Find records.
  Future<void> dbDeleteImpl(
    SdbDatabase db, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) {
    return db.inStoreTransaction(this, SdbTransactionMode.readWrite, (txn) {
      return txnDeleteImpl(
        txn.rawImpl,
        boundaries: boundaries,
        offset: offset,
        limit: limit,
        descending: descending,
      );
    });
  }

  /// Find records.
  Future<void> txnDeleteImpl(
    SdbTransactionImpl txn, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) {
    return txn
        .storeImpl(this)
        .deleteRecords(
          boundaries: boundaries,
          offset: offset,
          limit: limit,
          descending: descending,
        );
  }
}
