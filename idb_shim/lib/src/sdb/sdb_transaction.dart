import 'package:idb_shim/idb_sdb.dart';

import 'sdb_changes_listener.dart';
import 'sdb_client.dart';
import 'sdb_transaction_store.dart';

/// SimpleDb transaction.
abstract class SdbTransaction implements SdbClient {
  /// current mode for accessing the data in the object stores in the scope of
  /// the transaction
  SdbTransactionMode get mode;

  /// the database connection with which this transaction is associated.
  SdbDatabase get db;
}

/// SimpleDb transaction extension.
extension SdbTransactionExtension on SdbTransaction {
  /// transaction store.
  SdbTransactionStoreRef<K, V> store<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
  ) => txnInterface.txnStoreInterface<K, V>(store);
}

/// Transaction mode.
enum SdbTransactionMode {
  /// Open in read write mode.
  readWrite,

  /// Open in read only mode.
  readOnly,
}

/// Internal interface implemented by every transaction, idb based or not.
abstract class SdbTransactionInterface
    implements SdbTransaction, SdbClientInterface {
  /// The transaction store for [store].
  SdbTransactionStoreRefInterface<K, V> txnStoreInterface<
    K extends SdbKey,
    V extends SdbValue
  >(SdbStoreRef<K, V> store);

  /// The changes collected for the change listeners, null when no store is
  /// listened to (and during open).
  SdbDatabaseTransactionChanges? get changes;

  /// The change listeners of the database, null during open.
  SdbDatabaseChangesListener? get changesListener;

  /// Called when a write is performed on [storeName], for the cross tab
  /// notification.
  void noteWriteToStore(String storeName);
}

/// Internal extension.
extension SdbTransactionExtensionPrv on SdbTransaction {
  /// Internal interface.
  SdbTransactionInterface get txnInterface => this as SdbTransactionInterface;
}
