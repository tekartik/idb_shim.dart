import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import 'sdb_client.dart';

/// SimpleDb definition.
abstract class SdbDatabase implements SdbClient {
  /// Run a transaction.
  Future<T> inStoreTransaction<T, K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  );

  /// Run a transaction.
  Future<T> inStoresTransaction<T>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbMultiStoreTransaction txn) callback,
  );

  /// Run a transaction.
  /// Use either [storeNames] or [stores], mode default to read only
  Future<T> inTransaction<T>({
    List<String>? storeNames,
    List<SdbStoreRef>? stores,
    SdbTransactionMode? mode,
    required FutureOr<T> Function(SdbTransaction txn) run,
  });

  /// Get the version of the database.
  int get version;

  /// Get the name of the database.
  String get name;

  /// Factory
  SdbFactory get factory;

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
    FutureOr<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) {
    throw UnimplementedError('inStoreTransaction');
  }

  @override
  Future<T> inStoresTransaction<T>(
    List<SdbStoreRef<SdbKey, SdbValue>> stores,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbMultiStoreTransaction txn) callback,
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
