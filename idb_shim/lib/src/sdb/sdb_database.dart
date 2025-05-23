import 'sdb_client.dart';

import 'sdb_store.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_store.dart';
import 'sdb_types.dart';

/// SimpleDb definition.
abstract class SdbDatabase implements SdbClient {
  /// Run a transaction.
  Future<T> inStoreTransaction<T, K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    Future<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  );

  /// Run a transaction.
  Future<T> inStoresTransaction<T, K extends SdbKey, V extends SdbValue>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    Future<T> Function(SdbMultiStoreTransaction txn) callback,
  );

  /// Get the version of the database.
  int get version;

  /// Close the database.
  Future<void> close();
}

/// SimpleDb methods.
extension SdbDatabaseExtension on SdbDatabase {}

/// Default mixin
mixin SdbDatabaseDefaultMixin implements SdbDatabase, SdbClientInterface {
  @override
  Future<void> close() {
    throw UnimplementedError('close');
  }

  @override
  Future<T> inStoreTransaction<T, K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    Future<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) {
    throw UnimplementedError('inStoreTransaction');
  }

  @override
  Future<T> inStoresTransaction<T, K extends SdbKey, V extends SdbValue>(
    List<SdbStoreRef<SdbKey, SdbValue>> stores,
    SdbTransactionMode mode,
    Future<T> Function(SdbMultiStoreTransaction txn) callback,
  ) {
    throw UnimplementedError('inStoresTransaction');
  }

  @override
  Future<T> clientHandleDbOrTxn<T>(
    Future<T> Function(SdbDatabase db) dbFn,
    Future<T> Function(SdbTransaction txn) txnFn,
  ) {
    throw UnimplementedError('clientHandleDbOrTxn');
  }

  @override
  int get version => throw UnimplementedError('version');
}
