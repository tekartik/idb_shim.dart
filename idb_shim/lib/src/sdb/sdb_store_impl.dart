import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/sdb/sdb_find_options.dart';
import 'package:idb_shim/src/sdb/sdb_record_impl.dart';

import 'sdb.dart';
import 'sdb_client.dart';
import 'sdb_database_impl.dart';
import 'sdb_transaction_impl.dart';

/// Store reference internal extension.
extension SdbStoreRefInternalExtension<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// Store reference implementation.
  SdbStoreRefImpl<K, V> get impl => this as SdbStoreRefImpl<K, V>;
}

/// Store reference implementation.
extension SdbStoreRefDbExtension<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// Add a single record.

  Future<K> add(SdbClient client, V value) =>
      client.interface.sdbAddImpl<K, V>(this, value);

  /// Put a single record (when using inline keys)
  Future<K> put(SdbClient client, V value) => impl.putImpl(client, value);

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecords(
    SdbClient client, {

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
    options = compatMergeFindOptions(
      options,
      boundaries: boundaries,
      limit: limit,
      offset: offset,
      descending: descending,
      filter: filter,
    );
    return impl.findRecordsImpl(client, options: options);
  }

  /// Find first records
  Future<SdbRecordSnapshot<K, V>?> findRecord(
    SdbClient client, {

    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,

    /// Optional sort order
    bool? descending,

    /// New API, supercedes the other parameters
    SdbFindOptions<K>? options,
  }) async {
    options = compatMergeFindOptions(
      options,
      boundaries: boundaries,
      offset: offset,
      descending: descending,
      filter: filter,
    );
    options = options.copyWith(limit: 1);
    var records = await findRecords(client, options: options);
    return records.firstOrNull;
  }

  /// Find records.
  Future<List<SdbRecordKey<K, V>>> findRecordKeys(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) => impl.findRecordKeysImpl(
    client,
    options: compatMergeFindOptions(
      boundaries: boundaries,
      options,
      limit: limit,
      offset: offset,
      descending: descending,
    ),
  );

  /// Count records.
  Future<int> count(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) => impl.countImpl(
    client,
    options: compatMergeFindOptions(options, boundaries: boundaries),
  );

  /// Delete records.
  Future<void> delete(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) => impl.deleteImpl(
    client,
    options: compatMergeFindOptions(
      options,
      boundaries: boundaries,
      limit: limit,
      offset: offset,
      descending: descending,
    ),
  );

  /// Record reference.
  SdbRecordRef<K, V> record(K key) => SdbRecordRefImpl<K, V>(impl, key);
}

/// Store reference implementation.
class SdbStoreRefImpl<K extends SdbKey, V extends SdbValue>
    implements SdbStoreRef<K, V> {
  @override
  final String name;

  /// Store reference implementation.
  SdbStoreRefImpl(this.name) {
    if (!(K == int || K == String)) {
      throw ArgumentError('K type $K must be int or String');
    }
  }

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

    required SdbFindOptions<K> options,
  }) => client.handleDbOrTxn(
    (db) => dbFindRecordsImpl(db, options: options),
    (txn) => txnFindRecordsImpl(txn, options: options),
  );

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> dbFindRecordsImpl(
    SdbDatabase db, {

    required SdbFindOptions<K> options,
  }) {
    return db.inStoreTransaction(this, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordsImpl(txn.rawImpl, options: options);
    });
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> txnFindRecordsImpl(
    SdbTransactionImpl txn, {

    required SdbFindOptions<K> options,
  }) {
    return txn.storeImpl(this).findRecords(options: options);
  }

  /// Find records keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl(
    SdbClient client, {
    required SdbFindOptions<K> options,
  }) => client.handleDbOrTxn(
    (db) => dbFindRecordKeysImpl(db, options: options),
    (txn) => txnFindRecordKeysImpl(txn, options: options),
  );

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> dbFindRecordKeysImpl(
    SdbDatabase db, {
    required SdbFindOptions<K> options,
  }) {
    return db.inStoreTransaction(this, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordKeysImpl(txn.rawImpl, options: options);
    });
  }

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> txnFindRecordKeysImpl(
    SdbTransactionImpl txn, {
    required SdbFindOptions<K> options,
  }) {
    return txn.storeImpl(this).findRecordKeys(options: options);
  }

  /// Count records.
  Future<int> countImpl(SdbClient client, {SdbFindOptions<K>? options}) =>
      client.handleDbOrTxn(
        (db) => dbCountImpl(db, options: options),
        (txn) => txnCountImpl(txn, options: options),
      );

  /// Count records.
  Future<int> dbCountImpl(SdbDatabase db, {SdbFindOptions<K>? options}) {
    return db.inStoreTransaction(this, SdbTransactionMode.readOnly, (txn) {
      return txnCountImpl(txn.rawImpl, options: options);
    });
  }

  /// Count records.
  Future<int> txnCountImpl(
    SdbTransactionImpl txn, {
    SdbFindOptions<K>? options,
  }) {
    return txn.storeImpl(this).count(options: options);
  }

  /// Delete records.
  Future<void> deleteImpl(
    SdbClient client, {
    required SdbFindOptions<K> options,
  }) => client.handleDbOrTxn(
    (db) => dbDeleteImpl(db, options: options),
    (txn) => txnDeleteImpl(txn, options: options),
  );

  /// Find records.
  Future<void> dbDeleteImpl(
    SdbDatabase db, {
    required SdbFindOptions<K> options,
  }) {
    return db.inStoreTransaction(this, SdbTransactionMode.readWrite, (txn) {
      return txnDeleteImpl(txn.rawImpl, options: options);
    });
  }

  /// Find records.
  Future<void> txnDeleteImpl(
    SdbTransactionImpl txn, {

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) {
    return txn.storeImpl(this).deleteRecords(options: options);
  }
}
