import 'package:idb_shim/src/sdb/sdb_mixin.dart';

/// Database client (db or transaction).
abstract class SdbClient implements SdbClientIdbInterface {}

/// Database client idb interface
abstract class SdbClientIdbInterface {
  /// Object store names.
  Iterable<String> get storeNames;
}

/// Internal interface
abstract class SdbClientInterface {
  /// Handle db or transaction.
  Future<T> clientHandleDbOrTxn<T>(
    Future<T> Function(SdbDatabase db) dbFn,
    Future<T> Function(SdbTransaction txn) txnFn,
  ) {
    if (this is SdbTransaction) {
      return txnFn(this as SdbTransaction);
    } else {
      return dbFn(this as SdbDatabase);
    }
  }

  /// Add a record.
  Future<K> sdbAddImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    V value,
  );
}

/// Default mixin
mixin SdbClientInterfaceDefaultMixin implements SdbClientInterface {
  @override
  Future<K> sdbAddImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    V value,
  ) {
    throw UnimplementedError('$runtimeType.sdbAddImpl()');
  }
}

/// Internal extension
extension SdbClientExtensionPrv on SdbClient {
  /// Internal interface.
  SdbClientInterface get interface => this as SdbClientInterface;
}
