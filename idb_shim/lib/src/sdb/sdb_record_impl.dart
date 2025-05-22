import 'package:idb_shim/src/sdb/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_store_impl.dart';

// ignore: unused_import
import 'sdb_database_impl.dart';
import 'sdb_record_snapshot_impl.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction_impl.dart';
import 'sdb_types.dart';

/// Record reference internal extension.
extension SdbRecordRefInternalExtension<K extends KeyBase, V extends ValueBase>
    on SdbRecordRef<K, V> {
  /// Record reference implementation.
  SdbRecordRefImpl<K, V> get impl => this as SdbRecordRefImpl<K, V>;
}

/// Record reference implementation.
class SdbRecordRefImpl<K extends KeyBase, V extends ValueBase>
    implements SdbRecordRef<K, V> {
  @override
  final SdbStoreRefImpl<K, V> store;
  @override
  final K key;

  /// Record reference implementation.
  SdbRecordRefImpl(this.store, this.key);

  @override
  String toString() => 'Record(${store.name}, $key)';

  /// Get a single record.
  Future<SdbRecordSnapshotImpl<K, V>?> getImpl(SdbClient client) => client
      .handleDbOrTxn((db) => dbGetImpl(db), (txn) => txnGetImpl(txn.rawImpl));

  /// Get a single record.
  Future<SdbRecordSnapshotImpl<K, V>?> dbGetImpl(SdbDatabaseImpl db) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txn.impl.getRecordImpl(key);
    });
  }

  /// Get a single record.
  Future<SdbRecordSnapshotImpl<K, V>?> txnGetImpl(SdbTransactionImpl txn) {
    return txn.storeImpl(store).getRecordImpl(key);
  }

  /// Get a single record.
  Future<bool> existsImpl(SdbClient client) => client.handleDbOrTxn(
    (db) => dbExistsImpl(db),
    (txn) => txnExistsImpl(txn.rawImpl),
  );

  /// Get a single record.
  Future<bool> dbExistsImpl(SdbDatabaseImpl db) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txn.impl.existsImpl(key);
    });
  }

  /// Get a single record.
  Future<bool> txnExistsImpl(SdbTransactionImpl txn) {
    return txn.storeImpl(store).existsImpl(key);
  }

  /// Delete a single record.
  Future<void> deleteImpl(SdbClient client) => client.handleDbOrTxn(
    (db) => dbDeleteImpl(db),
    (txn) => txnDeleteImpl(txn.rawImpl),
  );

  /// Delete a single record.
  Future<void> dbDeleteImpl(SdbDatabaseImpl db) {
    return db.inStoreTransaction(store, SdbTransactionMode.readWrite, (txn) {
      return txn.delete(key);
    });
  }

  /// Delete a single record.
  Future<void> txnDeleteImpl(SdbTransactionImpl txn) {
    return txn.storeImpl(store).deleteImpl(key);
  }

  /// Put a single record.
  Future<void> putImpl(SdbClient client, V value) => client.handleDbOrTxn(
    (db) => dbPutImpl(db, value),
    (txn) => txnPutImpl(txn.rawImpl, value),
  );

  /// Put a single record.
  Future<void> dbPutImpl(SdbDatabaseImpl db, V value) {
    return db.inStoreTransaction(store, SdbTransactionMode.readWrite, (txn) {
      return txn.put(key, value);
    });
  }

  /// Put a single record.
  Future<void> txnPutImpl(SdbTransactionImpl txn, V value) {
    return txn.storeImpl(store).putImpl(key, value);
  }
}
