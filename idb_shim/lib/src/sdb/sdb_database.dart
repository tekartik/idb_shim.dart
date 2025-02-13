import 'sdb_client.dart';
import 'sdb_database_impl.dart';

import 'sdb_store.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_store.dart';
import 'sdb_types.dart';

/// SimpleDb definition.
abstract class SdbDatabase implements SdbClient {}

/// SimpleDb methods.
extension SdbDatabaseExtension on SdbDatabase {
  /// Run a transaction.
  Future<T> inStoreTransaction<T, K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    Future<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) => impl.inStoreTransactionImpl<T, K, V>(store, mode, callback);

  /// Run a transaction.
  Future<T> inStoresTransaction<T, K extends KeyBase, V extends ValueBase>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    Future<T> Function(SdbMultiStoreTransaction txn) callback,
  ) => impl.inStoresTransactionImpl<T>(stores, mode, callback);

  /// Close the database.
  Future<void> close() => impl.closeImpl();
}
