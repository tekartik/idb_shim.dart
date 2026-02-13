import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import 'sdb_client.dart';

/// SimpleDb database.
///
/// A database is a collection of stores.
/// The database has a version.
/// The database has a name.
/// The database has a factory.
///
/// A database can be opened using [SdbFactory.openDatabase].
///
/// A database can be closed using [SdbDatabase.close].
abstract class SdbDatabase implements SdbClient {
  /// Run a transaction on a single store.
  ///
  /// [store] is the store to run the transaction on.
  /// [mode] is the transaction mode, either [SdbTransactionMode.readOnly] or
  /// [SdbTransactionMode.readWrite].
  /// [callback] is the function to run in the transaction.
  Future<T> inStoreTransaction<T, K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  );

  /// Run a transaction on multiple stores.
  ///
  /// [stores] is the list of stores to run the transaction on.
  /// [mode] is the transaction mode, either [SdbTransactionMode.readOnly] or
  /// [SdbTransactionMode.readWrite].
  /// [callback] is the function to run in the transaction.
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
