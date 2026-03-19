import 'dart:async';

import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/src/common/common_import.dart';
import 'package:idb_shim/src/sdb/sdb_client.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_store_impl.dart';
import 'package:idb_shim/src/utils/async_utils.dart';
import 'package:idb_shim/src/utils/env_utils.dart';

import 'sdb.dart';
import 'sdb_changes_listener.dart';
import 'sdb_database_impl.dart';
import 'sdb_store_impl.dart';

/// SimpleDb transaction internal extension.
extension SdbTransactionInternalExtension on SdbTransaction {
  /// Transaction implementation.
  SdbTransactionImpl get rawImpl => this as SdbTransactionImpl;
}

/// Common transaction impl (between SdbTransactionImpl and SdbOpenTransactionImpl
abstract class SdbTransactionImpl implements SdbTransaction {
  /// Changes during transaction, only if listened to, null during open
  SdbDatabaseTransactionChanges? get changes;

  /// The underlying idb transaction
  idb.Transaction get idbTransaction;

  /// Change listener, null during open
  SdbDatabaseChangesListener? get changesListener;

  /// Store implementation.
  SdbTransactionStoreRefImpl<K, V>
  storeImpl<K extends SdbKey, V extends SdbValue>(SdbStoreRefImpl<K, V> store) {
    return SdbTransactionStoreRefImpl<K, V>.txn(this, store);
  }
}

/// Transaction implementation.
class SdbDatabaseTransactionImpl extends SdbTransactionImpl
    with SdbClientInterfaceDefaultMixin
    implements SdbTransaction, SdbClientInterface, SdbClientIdbInterface {
  /// Extra store names to open in addition to listened stores.
  /// during write transaction with changes listener.
  final List<String>? extraStoreNames;

  /// Database.
  final SdbDatabaseImpl db;

  /// Mode.
  @override
  final SdbTransactionMode mode;

  /// idb transaction.
  @override
  late idb.Transaction idbTransaction;

  /// Completed future.
  Future<void> get completed => idbTransaction.completed;

  /// Transaction implementation.
  SdbDatabaseTransactionImpl(
    this.db,
    this.mode, {
    required this.extraStoreNames,
  });

  /// Changes during transaction, only if listened to.
  @override
  SdbDatabaseTransactionChanges? changes;

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

  /// run in a transaction.
  Future<T> runCallback<T>(FutureOr<T> Function() callback) async {
    T result;
    try {
      /// Handle change listener
      var changesListener = this.changesListener;
      if (changesListener.hasListeners) {
        changes = SdbDatabaseTransactionChanges();
      }

      var rawResult = callback();

      if (rawResult is Future) {
        result = (await rawResult);
      } else {
        result = rawResult;
      }

      var txnChanges = changes;

      /// Handle end of transaction change
      if (txnChanges != null) {
        while (txnChanges.hasChanges) {
          try {
            /// Get all changes
            var storeChangesList = txnChanges.getAllStoreChanges().toList();
            if (storeChangesList.isEmpty) {
              break;
            }

            /// Clear changes
            txnChanges.clearChanges();
            var result = runSequentially(
              storeChangesList.map((item) {
                return () {
                  var store = item.$1;
                  var changes = item.$2;

                  var recordChanges = changes.getChanges();
                  var result = changesListener.handleStoreChanges(
                    this,
                    store,
                    recordChanges,
                  );
                  return result;
                };
              }).toList(),
            );
            if (result is Future) {
              await result;
            }
          } catch (e) {
            if (isDebug) {
              idbLog('Error handling changes listener: $e');
            }
            rethrow;
          }
        }
      }
    } finally {
      // wait for completion
      await completed;
    }
    return result;
  }

  @override
  SdbDatabaseChangesListener get changesListener => db.changesListener;
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
