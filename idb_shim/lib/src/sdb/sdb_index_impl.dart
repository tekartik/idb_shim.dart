import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/sdb/sdb_filter_impl.dart';
import 'package:idb_shim/src/sdb/sdb_utils.dart';
import 'package:idb_shim/src/utils/cursor_utils.dart';
import 'package:idb_shim/src/utils/idb_utils.dart';

import 'import_idb.dart' as idb;
import 'sdb_boundary.dart';
import 'sdb_boundary_impl.dart';
import 'sdb_client.dart';
import 'sdb_database.dart';
import 'sdb_database_impl.dart';
import 'sdb_filter.dart';
import 'sdb_index.dart';
import 'sdb_index_record_snapshot.dart';
import 'sdb_index_record_snapshot_impl.dart';
import 'sdb_key_utils.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_impl.dart';
import 'sdb_types.dart';

/// Index reference internal extension.
extension SdbIndexRefInternalExtension<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndexRef<K, V, I> {
  /// Index reference implementation.
  SdbIndexRefImpl<K, V, I> get impl => this as SdbIndexRefImpl<K, V, I>;
}

/// Index on 1 field.
class SdbIndex1RefImpl<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    extends SdbIndexRefImpl<K, V, I>
    implements SdbIndex1Ref<K, V, I> {
  /// Index on 1 field.
  SdbIndex1RefImpl(super.store, super.name);
}

/// Index on 2 fields
class SdbIndex2RefImpl<
  K extends SdbKey,
  V extends SdbValue,
  I1 extends SdbIndexKey,
  I2 extends SdbIndexKey
>
    extends SdbIndexRefImpl<K, V, (I1, I2)>
    implements SdbIndex2Ref<K, V, I1, I2> {
  /// Index on 2 fields.
  SdbIndex2RefImpl(super.store, super.name);
}

/// Index on 3 fields
class SdbIndex3RefImpl<
  K extends SdbKey,
  V extends SdbValue,
  I1 extends SdbIndexKey,
  I2 extends SdbIndexKey,
  I3 extends SdbIndexKey
>
    extends SdbIndexRefImpl<K, V, (I1, I2, I3)>
    implements SdbIndex3Ref<K, V, I1, I2, I3> {
  /// Index on 3 fields.
  SdbIndex3RefImpl(super.store, super.name);
}

/// Index on 4 fields
class SdbIndex4RefImpl<
  K extends SdbKey,
  V extends SdbValue,
  I1 extends SdbIndexKey,
  I2 extends SdbIndexKey,
  I3 extends SdbIndexKey,
  I4 extends SdbIndexKey
>
    extends SdbIndexRefImpl<K, V, (I1, I2, I3, I4)>
    implements SdbIndex4Ref<K, V, I1, I2, I3, I4> {
  /// Index on 4 fields.
  SdbIndex4RefImpl(super.store, super.name);
}

/// Index reference extension.
class SdbIndexRefImpl<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbIndexRef<K, V, I> {
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
    SdbClient client, {
    SdbBoundaries<I>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,
    bool? descending,
  }) => client.handleDbOrTxn(
    (db) => dbFindRecordsImpl(
      db,
      boundaries: boundaries,
      filter: filter,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
    (txn) => txnFindRecordsImpl(
      txn,
      boundaries: boundaries,
      filter: filter,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
  );

  /// Find records.
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeysImpl(
    SdbClient client, {
    SdbBoundaries<I>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) => client.handleDbOrTxn(
    (db) => dbFindRecordKeysImpl(
      db,
      boundaries: boundaries,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
    (txn) => txnFindRecordKeysImpl(
      txn,
      boundaries: boundaries,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
  );

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> dbFindRecordsImpl(
    SdbDatabaseImpl db, {
    SdbBoundaries<I>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,
    bool? descending,
  }) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordsImpl(
        txn.rawImpl,
        boundaries: boundaries,
        filter: filter,
        offset: offset,
        limit: limit,
        descending: descending,
      );
    });
  }

  /// Find record keys.
  Future<List<SdbIndexRecordKey<K, V, I>>> dbFindRecordKeysImpl(
    SdbDatabaseImpl db, {
    SdbBoundaries<I>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordKeysImpl(
        txn.rawImpl,
        boundaries: boundaries,
        offset: offset,
        limit: limit,
        descending: descending,
      );
    });
  }

  SdbIndexRecordSnapshotImpl<K, V, I> _sdbIndexRecordSnapshot(
    idb.CursorRow row,
  ) {
    var key = row.primaryKey as K;
    var indexKey = idbKeyToIndexKey<I>(row.key);
    var value = row.value as V;
    return SdbIndexRecordSnapshotImpl<K, V, I>(this, key, value, indexKey);
  }

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> txnFindRecordsImpl(
    SdbTransactionImpl txn, {
    SdbBoundaries<I>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,
    bool? descending,
  }) async {
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    var cursor = idbIndex.openCursor(
      direction: descendingToIdbDirection(descending),
      range: idbKeyRangeFromBoundaries(boundaries),
    );
    var rows = await cursor.toRowList(
      limit: limit,
      offset: offset,
      matcher: filter != null
          ? (cwv) => sdbCursorWithValueMatchesFilter(cwv, filter)
          : null,
    );

    return rows.map(_sdbIndexRecordSnapshot).toList();
  }

  /// Find record keys.
  Future<List<SdbIndexRecordKey<K, V, I>>> txnFindRecordKeysImpl(
    SdbTransactionImpl txn, {
    SdbBoundaries<I>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) async {
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    var cursor = idbIndex.openKeyCursor(
      direction: descendingToIdbDirection(descending),
      range: idbKeyRangeFromBoundaries(boundaries),
    );
    var rows = await cursor.toKeyRowList(limit: limit, offset: offset);
    return rows.map((row) {
      var key = row.primaryKey as K;
      var indexKey = idbKeyToIndexKey<I>(row.key);
      return SdbIndexRecordKeyImpl<K, V, I>(this, key, indexKey);
    }).toList();
  }

  /// Count records.
  Future<int> countImpl(SdbClient client, {SdbBoundaries<I>? boundaries}) =>
      client.handleDbOrTxn(
        (db) => dbCountImpl(db, boundaries: boundaries),
        (txn) => txnCountImpl(txn, boundaries: boundaries),
      );

  /// Count records.
  Future<int> dbCountImpl(SdbDatabase db, {SdbBoundaries<I>? boundaries}) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txnCountImpl(txn.rawImpl, boundaries: boundaries);
    });
  }

  /// Find record keys.
  Future<int> txnCountImpl(
    SdbTransactionImpl txn, {
    SdbBoundaries<I>? boundaries,
  }) async {
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    var count = idbIndex.count(idbKeyRangeFromBoundaries(boundaries));
    return count;
  }

  /// Delete records.
  Future<void> deleteImpl(
    SdbClient client, {
    SdbBoundaries<I>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) => client.handleDbOrTxn(
    (db) => dbDeleteImpl(
      db,
      boundaries: boundaries,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
    (txn) => txnDeleteImpl(
      txn,
      boundaries: boundaries,
      offset: offset,
      limit: limit,
      descending: descending,
    ),
  );

  /// Find records.
  Future<void> dbDeleteImpl(
    SdbDatabase db, {
    SdbBoundaries<I>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) {
    return db.inStoreTransaction(store, SdbTransactionMode.readWrite, (txn) {
      return txnDeleteImpl(
        txn.rawImpl,
        boundaries: boundaries,
        offset: offset,
        limit: limit,
        descending: descending,
      );
    });
  }

  /// Delete records.
  Future<void> txnDeleteImpl(
    SdbTransactionImpl txn, {
    SdbBoundaries<I>? boundaries,
    int? offset,
    int? limit,
    bool? descending,
  }) async {
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    // Need full cursor for delete
    var stream = idbIndex.openCursor(
      autoAdvance: true,
      direction: descendingToIdbDirection(descending),
      range: idbKeyRangeFromBoundaries(boundaries),
    );
    await streamWithOffsetAndLimit(stream, offset, limit).listen((cursor) {
      cursor.delete();
    }).asFuture<void>();
  }
}
