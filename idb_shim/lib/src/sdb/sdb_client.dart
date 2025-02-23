import 'package:idb_shim/sdb.dart';

/// Database client (db or transaction).
abstract class SdbClient {}

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
}
