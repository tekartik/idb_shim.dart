import 'package:idb_shim/idb_shim.dart' as idb;

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
class SdbDatabaseImpl implements SdbDatabase {
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
  Future<T> inStoreTransactionImpl<T, K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    Future<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) async {
    var txnStore = SdbTransactionStoreRefImpl<K, V>(store.impl);
    var txn = SdbSingleStoreTransactionImpl(impl, mode, txnStore);
    return txn.run(callback);
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

  /// Close the database.
  Future<void> closeImpl() async {
    idbDatabase.close();
  }
}
