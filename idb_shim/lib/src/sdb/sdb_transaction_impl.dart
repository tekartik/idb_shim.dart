import 'dart:async';

import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/src/sdb/sdb_client.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_store_impl.dart';

import 'sdb.dart';
import 'sdb_changes_listener.dart';
import 'sdb_database_impl.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_store.dart';

/// SimpleDb transaction internal extension.
extension SdbTransactionInternalExtension on SdbTransaction {
  /// Transaction implementation.
  SdbTransactionImpl get rawImpl => this as SdbTransactionImpl;

  /// Codec used
  SdbCodec get codec => db.interface.codec;
}

/// Common transaction impl (between SdbTransactionImpl and SdbOpenTransactionImpl
abstract class SdbTransactionImpl implements SdbTransactionInterface {
  /// Changes during transaction, only if listened to, null during open
  @override
  SdbDatabaseTransactionChanges? get changes;

  /// The underlying idb transaction
  idb.Transaction get idbTransaction;

  /// Change listener, null during open
  @override
  SdbDatabaseChangesListener? get changesListener;

  /// Called when a write is performed on [storeName]. No-op by default.
  @override
  void noteWriteToStore(String storeName) {}

  /// Store implementation.
  SdbTransactionStoreRefImpl<K, V>
  storeImpl<K extends SdbKey, V extends SdbValue>(SdbStoreRefImpl<K, V> store) {
    return SdbTransactionStoreRefImpl<K, V>.txn(this, store);
  }

  @override
  SdbTransactionStoreRefInterface<K, V> txnStoreInterface<
    K extends SdbKey,
    V extends SdbValue
  >(SdbStoreRef<K, V> store) => storeImpl<K, V>(store.impl);
}

/// Transaction implementation.
class SdbDatabaseTransactionImpl extends SdbTransactionImpl
    with SdbClientInterfaceDefaultMixin, SdbTransactionChangesDefaultMixin
    implements SdbTransaction, SdbClientInterface, SdbClientIdbInterface {
  /// Transaction implementation.
  SdbDatabaseTransactionImpl(
    this.db,
    this.mode, {
    required this.extraStoreNames,
  });

  /// Extra store names to open in addition to listened stores.
  /// during write transaction with changes listener.
  final List<String>? extraStoreNames;

  /// Database.
  @override
  final SdbDatabaseImpl db;

  /// Mode.
  @override
  final SdbTransactionMode mode;

  /// idb transaction.
  @override
  late idb.Transaction idbTransaction;

  /// Completed future.
  Future<void> get completed => idbTransaction.completed;

  @override
  Future<T> clientHandleDbOrTxn<T>(
    Future<T> Function(SdbDatabase db) dbFn,
    Future<T> Function(SdbTransaction txn) txnFn,
  ) {
    return txnFn(this);
  }

  @override
  Future<K> sdbAddImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    V value,
  ) {
    return storeImpl<K, V>(store.impl).add(value);
  }

  @override
  Iterable<String> get storeNames => idbTransaction.objectStoreNames;

  /// run in a transaction, the change listeners included.
  Future<T> runCallback<T>(FutureOr<T> Function() callback) async {
    T result;
    try {
      result = await runWithChangesListener(callback);
    } finally {
      // wait for completion
      await completed;
    }
    broadcastWrittenStores();
    return result;
  }

  @override
  SdbCodec get codec => db.codec;
}

/// Transaction mode conversion.
String idbTransactionMode(SdbTransactionMode mode) {
  switch (mode) {
    case SdbTransactionMode.readOnly:
      return idb.idbModeReadOnly;
    case SdbTransactionMode.readWrite:
      return idb.idbModeReadWrite;
  }
}
