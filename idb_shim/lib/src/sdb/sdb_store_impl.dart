import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/sdb/sdb_record_impl.dart';

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
  }) => impl.findRecordsImpl(
    client,
    boundaries: boundaries,
    filter: filter,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// Find firest records
  Future<SdbRecordSnapshot<K, V>?> findRecord(
    SdbClient client, {

    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,

    /// Optional sort order
    bool? descending,
  }) async {
    var records = await findRecords(
      client,
      boundaries: boundaries,
      filter: filter,
      offset: offset,
      limit: 1,
      descending: descending,
    );
    return records.firstOrNull;
  }

  /// Find records.
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
  Future<int> count(SdbClient client, {SdbBoundaries<K>? boundaries}) =>
      impl.countImpl(client, boundaries: boundaries);

  /// Delete records.
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
