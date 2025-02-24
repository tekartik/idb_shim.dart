import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:idb_shim/src/sdb/sdb_client.dart';

import 'sdb_database.dart';
import 'sdb_factory_impl.dart';
import 'sdb_store.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_store.dart';
import 'sdb_transaction_store_impl.dart';
import 'sdb_types.dart';

/// SimpleDb database internal extension.
extension SdbDatabaseInternalExtension on SdbDatabase {
  /// Database implementation.
  SdbDatabaseImpl get impl => this as SdbDatabaseImpl;
}

/// SimpleDb implementation.
class SdbDatabaseImpl
    with SdbClientInterfaceDefaultMixin, SdbDatabaseDefaultMixin
    implements SdbDatabase, SdbClientInterface {
  /// Factory.
  final SdbFactoryImpl factory;

  /// Name.
  final String name;

  /// Version.
  final int? version;

  /// Set after open.
  late idb.Database idbDatabase;

  /// SimpleDb implementation.
  SdbDatabaseImpl(this.factory, this.name, this.version);

  /// Transaction.
  @override
  Future<T> inStoreTransaction<T, K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    Future<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) async {
    var txnStore = SdbTransactionStoreRefImpl<K, V>(store.impl);
    var txn = SdbSingleStoreTransactionImpl(impl, mode, txnStore);
    return txn.run(callback);
  }

  @override
  Future<T> inStoresTransaction<T, K extends KeyBase, V extends ValueBase>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    Future<T> Function(SdbMultiStoreTransaction txn) callback,
  ) {
    return inStoresTransactionImpl(stores, mode, callback);
  }

  /// Run a transaction.
  Future<T> inStoresTransactionImpl<T>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    Future<T> Function(SdbMultiStoreTransaction txn) callback,
  ) async {
    var txn = SdbMultiStoreTransactionImpl(impl, mode, stores);
    return txn.run(callback);
  }

  @override
  Future<T> clientHandleDbOrTxn<T>(
    Future<T> Function(SdbDatabase db) dbFn,
    Future<T> Function(SdbTransaction txn) txnFn,
  ) {
    return dbFn(this);
  }

  /// Close the database.
  @override
  Future<void> close() async {
    idbDatabase.close();
  }

  @override
  Future<K> sdbAddImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    V value,
  ) {
    return inStoreTransaction<K, K, V>(store, SdbTransactionMode.readWrite, (
      txn,
    ) {
      return txn.add(value);
    });
  }
}
