import 'package:idb_shim/src/sdb/sdb_transaction_impl.dart';

import 'sdb_client.dart';
import 'sdb_database_impl.dart';

/// Database client (db or transaction).
extension SdbClientInternalExtension on SdbClient {
  /// Database implementation.
  SdbDatabaseImpl get dbImpl => this as SdbDatabaseImpl;

  /// Transaction implementation.
  SdbTransactionImpl get txnImpl => this as SdbTransactionImpl;

  /// Handle db or transaction.
  Future<T> handleDbOrTxn<T>(
    Future<T> Function(SdbDatabaseImpl db) dbFn,
    Future<T> Function(SdbTransactionImpl txn) txnFn,
  ) {
    if (this is SdbTransactionImpl) {
      return txnFn(txnImpl);
    } else {
      return dbFn(dbImpl);
    }
  }
}
