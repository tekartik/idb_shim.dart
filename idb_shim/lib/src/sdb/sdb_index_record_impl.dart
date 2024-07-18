import 'package:idb_shim/src/sdb/sdb_client_impl.dart';

import 'sdb_client.dart';
import 'sdb_database.dart';
import 'sdb_database_impl.dart';
import 'sdb_index_impl.dart';
import 'sdb_index_record.dart';
import 'sdb_index_record_snapshot_impl.dart';
import 'sdb_key_utils.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_impl.dart';
import 'sdb_types.dart';

/// Index record reference internal extension.
extension SdbIndexRecordRefInternalExtension<K extends KeyBase,
    V extends ValueBase, I extends IndexBase> on SdbIndexRecordRef<K, V, I> {
  /// Index record reference implementation.
  SdbIndexRecordRefImpl<K, V, I> get impl =>
      this as SdbIndexRecordRefImpl<K, V, I>;
}

/// Index record reference implementation.
class SdbIndexRecordRefImpl<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> implements SdbIndexRecordRef<K, V, I> {
  @override
  final SdbIndexRefImpl<K, V, I> index;
  @override
  final I indexKey;

  /// Index record reference implementation.
  SdbIndexRecordRefImpl(this.index, this.indexKey);

  @override
  SdbStoreRef<K, V> get store => index.store;
}

/// Index record reference extension.
extension SdbIndexRecordRefImplExtension<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> on SdbIndexRecordRef<K, V, I> {
  /// Get a single record.
  Future<SdbIndexRecordSnapshotImpl<K, V, I>?> getImpl(SdbClient client) =>
      client.handleDbOrTxn(dbGetImpl, txnGetImpl);

  /// Get a single record.
  Future<SdbIndexRecordSnapshotImpl<K, V, I>?> dbGetImpl(
      SdbDatabaseImpl db) async {
    return await db.inStoreTransaction(store, SdbTransactionMode.readOnly,
        (txn) {
      return txnGetImpl(txn.rawImpl);
    });
  }

  /// Get a single record.
  Future<SdbIndexRecordSnapshotImpl<K, V, I>?> txnGetImpl(
      SdbTransactionImpl txn) async {
    var idbStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbStore.index(index.name);
    var idbIndexKey = indexKeyToIdbKey(indexKey);
    var key = await idbIndex.getKey(idbIndexKey);
    if (key != null) {
      var result = await idbStore.getObject(key);
      if (result != null) {
        return SdbIndexRecordSnapshotImpl<K, V, I>(
            index.impl, key as K, fixResult<V>(result), indexKey);
      }
    }
    return null;
  }
}
