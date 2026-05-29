import 'package:idb_shim/src/sdb/sdb_codec.dart';
import 'package:idb_shim/src/sdb/sdb_store_impl.dart';

import 'sdb_client.dart';
import 'sdb_index_impl.dart';
import 'sdb_index_record.dart';
import 'sdb_index_record_snapshot_impl.dart';
import 'sdb_key_utils.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_impl.dart';
import 'sdb_types.dart';

/// Index record reference internal extension.
extension SdbIndexRecordRefInternalExtension<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndexRecordRef<K, V, I> {
  /// Index record reference implementation.
  SdbIndexRecordRefImpl<K, V, I> get impl =>
      this as SdbIndexRecordRefImpl<K, V, I>;
}

/// Index record reference implementation.
class SdbIndexRecordRefImpl<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbIndexRecordRef<K, V, I> {

  /// Index record reference implementation.
  SdbIndexRecordRefImpl(this.index, this.indexKey);
  @override
  final SdbIndexRefImpl<K, V, I> index;
  @override
  final I indexKey;

  @override
  SdbStoreRefImpl<K, V> get store => index.store;
}

/// Index record reference extension.
extension SdbIndexRecordRefImplExtension<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndexRecordRef<K, V, I> {
  /// Get a single record.
  Future<SdbIndexRecordSnapshotImpl<K, V, I>?> getImpl(SdbClient client) =>
      impl.store.clientAutoTxnImpl(
        client,
        SdbTransactionMode.readOnly,
        (txn) => txnGetImpl(txn.rawImpl),
      );

  /// Get a single record key.
  Future<K?> getKeyImpl(SdbClient client) => impl.store.clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,
    (txn) => txnGetKeyImpl(txn.rawImpl),
  );

  /// Get a single record.
  Future<SdbIndexRecordSnapshotImpl<K, V, I>?> txnGetImpl(
    SdbTransactionImpl txn,
  ) async {
    var idbStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbStore.index(index.name);
    var codec = txn.codec;
    var idbIndexKey = sdbIndexKeyToIdbKey(codec, indexKey);
    var key = await idbIndex.getKey(idbIndexKey);
    if (key != null) {
      var result = await idbStore.getObject(key);
      if (result != null) {
        return SdbIndexRecordSnapshotImpl<K, V, I>(
          index.impl,
          key as K,
          codec.decode<V>(result),
          indexKey,
        );
      }
    }
    return null;
  }

  /// Get a single record primary key.
  Future<K?> txnGetKeyImpl(SdbTransactionImpl txn) async {
    var idbStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbStore.index(index.name);
    var idbIndexKey = sdbIndexKeyToIdbKey(txn.codec, indexKey);
    var key = (await idbIndex.getKey(idbIndexKey)) as K?;
    return key;
  }
}
