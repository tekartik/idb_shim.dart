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
import 'sdb_key_utils.dart';
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

/// Index on 1 field.
class SdbIndex1RefImpl<K extends KeyBase, V extends ValueBase,
        I extends IndexBase> extends SdbIndexRefImpl<K, V, I>
    implements SdbIndex1Ref<K, V, I> {
  /// Index on 1 field.
  SdbIndex1RefImpl(super.store, super.name);
}

/// Index on 2 fields
class SdbIndex2RefImpl<
        K extends KeyBase,
        V extends ValueBase,
        I1 extends IndexBase,
        I2 extends IndexBase> extends SdbIndexRefImpl<K, V, (I1, I2)>
    implements SdbIndex2Ref<K, V, I1, I2> {
  /// Index on 2 fields.
  SdbIndex2RefImpl(super.store, super.name);
}

/// Index on 3 fields
class SdbIndex3RefImpl<
        K extends KeyBase,
        V extends ValueBase,
        I1 extends IndexBase,
        I2 extends IndexBase,
        I3 extends IndexBase> extends SdbIndexRefImpl<K, V, (I1, I2, I3)>
    implements SdbIndex3Ref<K, V, I1, I2, I3> {
  /// Index on 3 fields.
  SdbIndex3RefImpl(super.store, super.name);
}

/// Index on 4 fields
class SdbIndex4RefImpl<
        K extends KeyBase,
        V extends ValueBase,
        I1 extends IndexBase,
        I2 extends IndexBase,
        I3 extends IndexBase,
        I4 extends IndexBase> extends SdbIndexRefImpl<K, V, (I1, I2, I3, I4)>
    implements SdbIndex4Ref<K, V, I1, I2, I3, I4> {
  /// Index on 4 fields.
  SdbIndex4RefImpl(super.store, super.name);
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
          {SdbBoundaries<I>? boundaries,
          int? offset,
          int? limit}) =>
      client.handleDbOrTxn(
          (db) => dbFindRecordsImpl(db,
              boundaries: boundaries, offset: offset, limit: limit),
          (txn) => txnFindRecordsImpl(txn,
              boundaries: boundaries, offset: offset, limit: limit));

  /// Find records.
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeysImpl(SdbClient client,
          {SdbBoundaries<I>? boundaries, int? offset, int? limit}) =>
      client.handleDbOrTxn(
          (db) => dbFindRecordKeysImpl(db,
              boundaries: boundaries, offset: offset, limit: limit),
          (txn) => txnFindRecordKeysImpl(txn,
              boundaries: boundaries, offset: offset, limit: limit));

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> dbFindRecordsImpl(
      SdbDatabaseImpl db,
      {SdbBoundaries<I>? boundaries,
      int? offset,
      int? limit}) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordsImpl(txn.rawImpl,
          boundaries: boundaries, offset: offset, limit: limit);
    });
  }

  /// Find record keys.
  Future<List<SdbIndexRecordKey<K, V, I>>> dbFindRecordKeysImpl(
      SdbDatabaseImpl db,
      {SdbBoundaries<I>? boundaries,
      int? offset,
      int? limit}) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordKeysImpl(txn.rawImpl,
          boundaries: boundaries, offset: offset, limit: limit);
    });
  }

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> txnFindRecordsImpl(
      SdbTransactionImpl txn,
      {SdbBoundaries<I>? boundaries,
      int? offset,
      int? limit}) async {
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    var cursor = idbIndex.openCursor(
        autoAdvance: true,
        direction: idb.idbDirectionNext,
        range: idbKeyRangeFromBoundaries(boundaries));
    var rows = await idb.cursorToList(cursor, offset, limit);
    return rows.map((row) {
      var key = row.primaryKey as K;
      var indexKey = idbKeyToIndexKey<I>(row.key as Object);
      var value = row.value as V;
      return SdbIndexRecordSnapshotImpl<K, V, I>(this, key, value, indexKey);
    }).toList();
  }

  /// Find record keys.
  Future<List<SdbIndexRecordKey<K, V, I>>> txnFindRecordKeysImpl(
      SdbTransactionImpl txn,
      {SdbBoundaries<I>? boundaries,
      int? offset,
      int? limit}) async {
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    var cursor = idbIndex.openKeyCursor(
        autoAdvance: true,
        direction: idb.idbDirectionNext,
        range: idbKeyRangeFromBoundaries(boundaries));
    var rows = await idb.keyCursorToList(cursor, offset, limit);
    return rows.map((row) {
      var key = row.primaryKey as K;
      var indexKey = idbKeyToIndexKey<I>(row.key as Object);

      return SdbIndexRecordKeyImpl<K, V, I>(this, key, indexKey);
    }).toList();
  }
}
