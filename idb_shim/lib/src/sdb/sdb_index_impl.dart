import 'dart:async';
import 'dart:math';

import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/sdb/sdb_filter_impl.dart';
import 'package:idb_shim/src/sdb/sdb_utils.dart';
import 'package:idb_shim/src/utils/cursor_utils.dart';
import 'package:idb_shim/src/utils/idb_utils.dart';

import 'import_idb.dart' as idb;
import 'sdb.dart';
import 'sdb_boundary_impl.dart';
import 'sdb_database_impl.dart';
import 'sdb_index_record_snapshot_impl.dart';
import 'sdb_key_utils.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction_impl.dart';

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

    required SdbFindOptions<I> options,
  }) => client.handleDbOrTxn(
    (db) => dbFindRecordsImpl(db, options: options),
    (txn) => txnFindRecordsImpl(txn, options: options),
  );

  /// Find records.
  Stream<SdbIndexRecordSnapshot<K, V, I>> streamRecordsImpl(
    SdbClient client, {

    required SdbFindOptions<I> options,
  }) => client.handleDbOrTxn(
    (db) => dbStreamRecordsImpl(db, options: options),
    (txn) => txnStreamRecordsImpl(txn, options: options),
  );

  /// Find records.
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeysImpl(
    SdbClient client, {

    required SdbFindOptions<I> options,
  }) {
    return client.handleDbOrTxn(
      (db) => dbFindRecordKeysImpl(db, options: options),
      (txn) => txnFindRecordKeysImpl(txn, options: options),
    );
  }

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> dbFindRecordsImpl(
    SdbDatabaseImpl db, {

    required SdbFindOptions<I> options,
  }) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordsImpl(txn.rawImpl, options: options);
    });
  }

  /// Find records.
  Stream<SdbIndexRecordSnapshot<K, V, I>> dbStreamRecordsImpl(
    SdbDatabaseImpl db, {

    required SdbFindOptions<I> options,
  }) {
    var ctlr = StreamController<SdbIndexRecordSnapshot<K, V, I>>(sync: true);
    db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) async {
      var stream = txnStreamRecordsImpl(txn.rawImpl, options: options);
      await ctlr.addStream(stream);
    });
    return ctlr.stream;
  }

  /// Find record keys.
  Future<List<SdbIndexRecordKey<K, V, I>>> dbFindRecordKeysImpl(
    SdbDatabaseImpl db, {

    /// filter ignored
    required SdbFindOptions<I> options,
  }) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txnFindRecordKeysImpl(txn.rawImpl, options: options);
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

  /// stream records.
  Stream<IdbCursorWithValue> txnStreamCursorImpl(
    SdbTransactionImpl txn, {

    required SdbFindOptions<I> options,
  }) {
    var descending = options.descending;

    var boundaries = options.boundaries;
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    var cursor = idbIndex.openCursor(
      direction: descendingToIdbDirection(descending),
      range: idbKeyRangeFromBoundaries(boundaries),
    );
    return cursor;
  }

  /// Find records.
  Stream<SdbIndexRecordSnapshot<K, V, I>> txnStreamRecordsImpl(
    SdbTransactionImpl txn, {

    required SdbFindOptions<I> options,
  }) {
    var offset = options.offset;
    var limit = options.limit;
    var filter = options.filter;

    var cursor = txnStreamCursorImpl(txn, options: options);
    return cursor
        .limitOffsetStream(
          limit: limit,
          offset: offset,
          matcher: filter != null
              ? (cwv) => sdbCursorWithValueMatchesFilter(cwv, filter)
              : null,
        )
        .map(_sdbIndexRecordSnapshot);
  }

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> txnFindRecordsImpl(
    SdbTransactionImpl txn, {

    required SdbFindOptions<I> options,
  }) async {
    var offset = options.offset;
    var limit = options.limit;
    var filter = options.filter;

    var cursor = txnStreamCursorImpl(txn, options: options);
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
  /// If a filter the whole record is read and filter applied in memory.
  Future<List<SdbIndexRecordKey<K, V, I>>> txnFindRecordKeysImpl(
    SdbTransactionImpl txn, {
    required SdbFindOptions<I> options,
  }) async {
    var filter = options.filter;
    if (filter != null) {
      return await txnFindRecordsImpl(txn, options: options);
    }
    var descending = options.descending;
    var offset = options.offset;
    var limit = options.limit;
    var boundaries = options.boundaries;
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
  Future<int> countImpl(
    SdbClient client, {
    required SdbFindOptions<I> options,
  }) => client.handleDbOrTxn(
    (db) => dbCountImpl(db, options: options),
    (txn) => txnCountImpl(txn, options: options),
  );

  /// Count records.
  Future<int> dbCountImpl(
    SdbDatabase db, {
    required SdbFindOptions<I> options,
  }) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return txnCountImpl(txn.rawImpl, options: options);
    });
  }

  /// Find record keys.
  Future<int> txnCountImpl(
    SdbTransactionImpl txn, {
    required SdbFindOptions<I> options,
  }) async {
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    var filter = options.filter;
    var boundaries = options.boundaries;
    var limit = options.limit;
    var offset = options.offset;
    if (filter != null) {
      var records = await txnFindRecordsImpl(txn, options: options);
      return records.length;
    }
    var count = await idbIndex.count(idbKeyRangeFromBoundaries(boundaries));
    if ((offset ?? -1) > 0) {
      count = max(0, count - offset!);
    }
    if ((limit ?? -1) > 0) {
      count = max(count, limit!);
    }

    return count;
  }

  /// Delete records.
  Future<void> deleteImpl(
    SdbClient client, {
    required SdbFindOptions<I> options,
  }) => client.handleDbOrTxn(
    (db) => dbDeleteImpl(db, options: options),
    (txn) => txnDeleteImpl(txn, options: options),
  );

  /// Find records.
  Future<void> dbDeleteImpl(
    SdbDatabase db, {
    required SdbFindOptions<I> options,
  }) {
    return db.inStoreTransaction(store, SdbTransactionMode.readWrite, (txn) {
      return txnDeleteImpl(txn.rawImpl, options: options);
    });
  }

  /// Delete records.
  Future<void> txnDeleteImpl(
    SdbTransactionImpl txn, {
    required SdbFindOptions<I> options,
  }) async {
    if (options.filter != null) {
      var records = await txnFindRecordKeysImpl(txn, options: options);
      for (var record in records) {
        await store.record(record.key).delete(txn);
      }
      return;
    }
    var descending = options.descending;
    var offset = options.offset;
    var limit = options.limit;
    var boundaries = options.boundaries;
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
