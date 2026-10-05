import 'package:idb_shim/src/sdb/sdb.dart';

import 'sdb_store_impl.dart';
import 'sdb_transaction.dart';

/// Record reference internal extension.
extension SdbRecordRefInternalExtension<K extends SdbKey, V extends SdbValue>
    on SdbRecordRef<K, V> {
  /// Record reference implementation.
  SdbRecordRefImpl<K, V> get impl => this as SdbRecordRefImpl<K, V>;
}

/// Record reference implementation.
class SdbRecordRefImpl<K extends SdbKey, V extends SdbValue>
    implements SdbRecordRef<K, V> {
  /// Record reference implementation.
  SdbRecordRefImpl(this.store, this.key);
  @override
  final SdbStoreRefImpl<K, V> store;
  @override
  final K key;

  @override
  String toString() => 'Record(${store.name}, $key)';

  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> getImpl(SdbClient client) =>
      impl.store.clientAutoTxnImpl(
        client,
        SdbTransactionMode.readOnly,
        (txn) => txnGetImpl(txn.txnInterface),
      );

  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> txnGetImpl(SdbTransactionInterface txn) {
    return txn.txnStoreInterface(store).getRecordImpl(key);
  }

  /// Get a single record.
  Future<bool> existsImpl(SdbClient client) => impl.store.clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,
    (txn) => txnExistsImpl(txn.txnInterface),
  );

  /// Get a single record.
  Future<bool> txnExistsImpl(SdbTransactionInterface txn) {
    return txn.txnStoreInterface(store).existsImpl(key);
  }

  /// Delete a single record.
  Future<void> deleteImpl(SdbClient client) => impl.store.clientAutoTxnImpl(
    client,
    SdbTransactionMode.readWrite,
    (txn) => txnDeleteImpl(txn.txnInterface),
  );

  /// Delete a single record.
  Future<void> txnDeleteImpl(SdbTransactionInterface txn) {
    return txn.txnStoreInterface(store).deleteImpl(key);
  }

  /// Put a single record.
  Future<void> putImpl(SdbClient client, V value) =>
      impl.store.clientAutoTxnImpl(
        client,
        SdbTransactionMode.readWrite,
        (txn) => txnPutImpl(txn.txnInterface, value),
      );

  /// Put a single record.
  Future<void> txnPutImpl(SdbTransactionInterface txn, V value) {
    return txn.txnStoreInterface(store).putImpl(key, value);
  }

  @override
  SdbRecordRef<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>() {
    if (this is SdbRecordRef<RK, RV>) {
      return this as SdbRecordRef<RK, RV>;
    }
    return store.cast<RK, RV>().record(key as RK);
  }

  @override
  int get hashCode => store.hashCode ^ key.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is SdbRecordRef) {
      return store == other.store && key == other.key;
    }
    return false;
  }
}
