import 'package:idb_shim/src/sdb/sdb_transaction_impl.dart';

import 'sdb_client.dart';
import 'sdb_database_impl.dart';
import 'sdb_transaction.dart';

/// Database client (db or transaction).
extension SdbClientExtension on SdbClient {}

/// Database client (db or transaction).
extension SdbClientInternalExtension on SdbClient {
  /// Database implementation.
  SdbDatabaseImpl get dbImpl =>
      (this is SdbTransaction) ? txnDbImpl : this as SdbDatabaseImpl;

  /// Transaction implementation.
  SdbTransactionImpl get txnImpl => this as SdbTransactionImpl;

  /// Transaction database implementation.
  SdbDatabaseImpl get txnDbImpl => txnImpl.db;

  /// Handle db or transaction.
  T handleDbOrTxnImpl<T>(
    T Function(SdbDatabaseImpl db) dbFn,
    T Function(SdbTransactionImpl txn) txnFn,
  ) {
    if (this is SdbTransactionImpl) {
      return txnFn(this as SdbTransactionImpl);
    } else {
      return dbFn(this as SdbDatabaseImpl);
    }
  }

  /// Handle db or transaction.
  T handleDbOrTxn<T>(
    T Function(SdbDatabaseImpl db) dbFn,
    T Function(SdbTransactionImpl txn) txnFn,
  ) {
    return handleDbOrTxnImpl(dbFn, txnFn);
  }
}
