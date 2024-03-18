import 'import_idb.dart' as idb;
import 'sdb_boundary.dart';
import 'sdb_boundary_impl.dart';
import 'sdb_client.dart';
import 'sdb_client_impl.dart';
import 'sdb_database.dart';
import 'sdb_database_impl.dart';
import 'sdb_index.dart';
import 'sdb_index_record_snapshot.dart';
import 'sdb_index_record_snapshot_impl.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_impl.dart';
import 'sdb_types.dart';

/// Index reference internal extension.
extension SdbIndexRefInternalExtension<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> on SdbIndexRef<K, V, I> {
  /// Index reference implementation.
  SdbIndexRefImpl<K, V, I> get impl => this as SdbIndexRefImpl<K, V, I>;
}

/// Index reference extension.
class SdbIndexRefImpl<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> implements SdbIndexRef<K, V, I> {
  @override
  final SdbStoreRefImpl<K, V> store;
  @override
  final String name;

  /// Index reference implementation.
  SdbIndexRefImpl(this.store, this.name);

  @override
  String toString() => 'Index(${store.name}, $name)';

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> findRecordsImpl(
          SdbClient client,
          {SdbBoundaries<I>? boundaries}) =>
      client.handleDbOrTxn(
          (db) => dbFindRecordsImpl(db, boundaries: boundaries),
          (txn) => txnFindRecordsImpl(txn, boundaries: boundaries));

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> dbFindRecordsImpl(
      SdbDatabaseImpl db,
      {SdbBoundaries<I>? boundaries}) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordsImpl(txn.rawImpl, boundaries: boundaries);
    });
  }

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> txnFindRecordsImpl(
      SdbTransactionImpl txn,
      {SdbBoundaries<I>? boundaries}) async {
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    var cursor = idbIndex.openCursor(
        autoAdvance: true,
        direction: idb.idbDirectionNext,
        range: idbKeyRangeFromBoundaries(boundaries));
    var rows = await idb.cursorToList(cursor);
    return rows.map((row) {
      var key = row.primaryKey as K;
      var indexKey = row.key as I;
      var value = row.value as V;
      return SdbIndexRecordSnapshotImpl<K, V, I>(this, key, value, indexKey);
    }).toList();
  }
}
