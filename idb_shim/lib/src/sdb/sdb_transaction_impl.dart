import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/src/sdb/sdb_client.dart';
import 'package:idb_shim/src/sdb/sdb_database.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_store_impl.dart';

import 'sdb_database_impl.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction.dart';
import 'sdb_types.dart';

/// SimpleDb transaction internal extension.
extension SdbTransactionInternalExtension on SdbTransaction {
  /// Transaction implementation.
  SdbTransactionImpl get rawImpl => this as SdbTransactionImpl;
}

/// Transaction implementation.
class SdbTransactionImpl implements SdbTransaction, SdbClientInterface {
  /// Database.
  final SdbDatabaseImpl db;

  /// Mode.
  final SdbTransactionMode mode;

  /// idb transaction.
  late idb.Transaction idbTransaction;

  /// Completed future.
  Future<void> get completed => idbTransaction.completed;

  /// Transaction implementation.
  SdbTransactionImpl(this.db, this.mode);

  /// Store implementation.
  SdbTransactionStoreRefImpl<K, V> storeImpl<
    K extends KeyBase,
    V extends ValueBase
  >(SdbStoreRefImpl<K, V> store) {
    return SdbTransactionStoreRefImpl<K, V>.txn(this, store);
  }

  @override
  Future<T> clientHandleDbOrTxn<T>(
    Future<T> Function(SdbDatabase db) dbFn,
    Future<T> Function(SdbTransaction txn) txnFn,
  ) {
    return txnFn(this);
  }
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
