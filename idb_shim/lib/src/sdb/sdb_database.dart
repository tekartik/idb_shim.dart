import 'sdb_client.dart';

import 'sdb_store.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_store.dart';
import 'sdb_types.dart';

/// SimpleDb definition.
abstract class SdbDatabase implements SdbClient {
  /// Run a transaction.
  Future<T> inStoreTransaction<T, K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    Future<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  );

  /// Run a transaction.
  Future<T> inStoresTransaction<T, K extends KeyBase, V extends ValueBase>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    Future<T> Function(SdbMultiStoreTransaction txn) callback,
  );

  /// Close the database.
  Future<void> close();
}

/// SimpleDb methods.
extension SdbDatabaseExtension on SdbDatabase {}

/// Default mixin
mixin SdbDatabaseDefaultMixin implements SdbDatabase {
  @override
  Future<void> close() {
    throw UnimplementedError('close');
  }

  @override
  Future<T> inStoreTransaction<T, K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    Future<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) {
    throw UnimplementedError('inStoreTransaction');
  }

  @override
  Future<T> inStoresTransaction<T, K extends KeyBase, V extends ValueBase>(
    List<SdbStoreRef<KeyBase, ValueBase>> stores,
    SdbTransactionMode mode,
    Future<T> Function(SdbMultiStoreTransaction txn) callback,
  ) {
    throw UnimplementedError('inStoresTransaction');
  }
}
