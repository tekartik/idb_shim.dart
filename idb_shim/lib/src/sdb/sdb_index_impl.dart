import 'dart:async';
import 'dart:math';

import 'package:idb_shim/src/common/common_paged_query.dart';
import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/sdb/sdb_codec.dart';
import 'package:idb_shim/src/sdb/sdb_filter_impl.dart';
import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/sdb/sdb_paged_iterate.dart';
import 'package:idb_shim/src/sdb/sdb_utils.dart';
import 'package:idb_shim/src/utils/cursor_utils.dart';
import 'package:idb_shim/src/utils/idb_utils.dart';

import 'import_idb.dart' as idb;
import 'sdb.dart';
import 'sdb_boundary_impl.dart';
import 'sdb_database_impl.dart';
import 'sdb_index_cursor.dart';
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
  SdbIndex1RefImpl(super.store, super.name) {
    sdbCheckIndexKeyType<I>();
  }

  /// Create store schema, keyPath is String, a `List<String>` or SdbKeyPath
  @override
  SdbIndexSchema indexSchema({required Object keyPath, bool? unique}) {
    var single = sdbKeySinglePathFromAny(keyPath);
    return SdbIndexSchema(
      this,
      SdbKeyPath.single(SdbCodec.defaultCodec.sdbKeyPath<I>(single.keyPath)),
      unique: unique ?? false,
    );
  }

  /// Convert idb key (typically direct in to index key.
  @override
  I indexIdbToSdbKeyValue(SdbCodec codec, Object key) {
    return codec.decodeKeyValue<I>(key);
  }
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
  SdbIndex2RefImpl(super.store, super.name) {
    sdbCheckIndexKeyType<I1>();
    sdbCheckIndexKeyType<I2>();
  }

  @override
  (I1, I2) indexIdbToSdbKeyValue(SdbCodec codec, Object key) {
    var list = (key as List).cast<Object>();
    return (
      codec.decodeKeyValue<I1>(list[0]),
      codec.decodeKeyValue<I2>(list[1]),
    );
  }

  @override
  SdbIndexSchema indexSchema({required Object keyPath, bool? unique}) {
    var multi = sdbKeyMultiPathFromAny(keyPath);
    return SdbIndexSchema(
      this,
      SdbKeyPath.multi([
        SdbCodec.defaultCodec.sdbKeyPath<I1>(multi.keyPaths[0]),
        SdbCodec.defaultCodec.sdbKeyPath<I2>(multi.keyPaths[1]),
      ]),
      unique: unique ?? false,
    );
  }
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
  SdbIndex3RefImpl(super.store, super.name) {
    sdbCheckIndexKeyType<I1>();
    sdbCheckIndexKeyType<I2>();
    sdbCheckIndexKeyType<I3>();
  }

  @override
  SdbIndexSchema indexSchema({required Object keyPath, bool? unique}) {
    var multi = sdbKeyMultiPathFromAny(keyPath);
    return SdbIndexSchema(
      this,
      SdbKeyPath.multi([
        SdbCodec.defaultCodec.sdbKeyPath<I1>(multi.keyPaths[0]),
        SdbCodec.defaultCodec.sdbKeyPath<I2>(multi.keyPaths[1]),
        SdbCodec.defaultCodec.sdbKeyPath<I3>(multi.keyPaths[2]),
      ]),
      unique: unique ?? false,
    );
  }

  @override
  (I1, I2, I3) indexIdbToSdbKeyValue(SdbCodec codec, Object key) {
    var list = (key as List).cast<Object>();
    return (
      codec.decodeKeyValue<I1>(list[0]),
      codec.decodeKeyValue<I2>(list[1]),
      codec.decodeKeyValue<I3>(list[2]),
    );
  }
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
  SdbIndex4RefImpl(super.store, super.name) {
    sdbCheckIndexKeyType<I1>();
    sdbCheckIndexKeyType<I2>();
    sdbCheckIndexKeyType<I3>();
    sdbCheckIndexKeyType<I4>();
  }

  @override
  SdbIndexSchema indexSchema({required Object keyPath, bool? unique}) {
    var multi = sdbKeyMultiPathFromAny(keyPath);
    return SdbIndexSchema(
      this,
      SdbKeyPath.multi([
        SdbCodec.defaultCodec.sdbKeyPath<I1>(multi.keyPaths[0]),
        SdbCodec.defaultCodec.sdbKeyPath<I2>(multi.keyPaths[1]),
        SdbCodec.defaultCodec.sdbKeyPath<I3>(multi.keyPaths[2]),
        SdbCodec.defaultCodec.sdbKeyPath<I4>(multi.keyPaths[3]),
      ]),
      unique: unique ?? false,
    );
  }

  @override
  (I1, I2, I3, I4) indexIdbToSdbKeyValue(SdbCodec codec, Object key) {
    var list = (key as List).cast<Object>();
    return (
      codec.decodeKeyValue<I1>(list[0]),
      codec.decodeKeyValue<I2>(list[1]),
      codec.decodeKeyValue<I3>(list[2]),
      codec.decodeKeyValue<I4>(list[3]),
    );
  }
}

/// Index reference extension.
abstract class SdbIndexRefImpl<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbIndexRef<K, V, I> {
  /// Index reference implementation.
  SdbIndexRefImpl(this.store, this.name);

  /// Convert idb key to index key.
  I indexIdbToSdbKeyValue(SdbCodec codec, Object key);

  /// Index schema to implement
  SdbIndexSchema indexSchema({required Object keyPath, bool? unique});
  @override
  final SdbStoreRefImpl<K, V> store;
  @override
  final String name;

  @override
  String toString() => 'Index(${store.name}, $name)';

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> findRecordsImpl(
    SdbClient client, {

    required SdbFindOptions<I> options,
  }) => impl.store.clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,

    (txn) => txnFindRecordsImpl(txn.rawImpl, options: options),
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
  }) => impl.store.clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,
    (txn) => txnFindRecordKeysImpl(txn.rawImpl, options: options),
  );

  /// Find records.
  Stream<SdbIndexRecordSnapshot<K, V, I>> dbStreamRecordsImpl(
    SdbDatabaseImpl db, {

    required SdbFindOptions<I> options,
  }) {
    var ctlr = SdbTxnStreamController<SdbIndexRecordSnapshot<K, V, I>>();
    db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) async {
      var stream = txnStreamRecordsImpl(txn.rawImpl, options: options);
      await ctlr.addStream(stream);
    });
    return ctlr.stream;
  }

  SdbIndexRecordSnapshotImpl<K, V, I> _sdbIndexRecordSnapshot(
    SdbCodec codec,
    idb.CursorRow row,
  ) {
    var key = row.primaryKey as K;
    var indexKey = indexIdbToSdbKeyValue(codec, row.key);
    var value = codec.decode<V>(row.value);
    return SdbIndexRecordSnapshotImpl<K, V, I>(this, key, value, indexKey);
  }

  /// Stream the rows of the query, filter, offset and limit applied.
  ///
  /// Read natively page by page when the implementation supports it (sql
  /// LIMIT/OFFSET), else by walking a cursor. Was returning the raw idb
  /// cursors (txnStreamCursorImpl), which a cursor-less paged read cannot
  /// produce, so it hands out rows instead.
  Stream<IdbCursorRow> txnStreamRowsImpl(
    SdbTransactionImpl txn, {
    required SdbFindOptions<I> options,
  }) {
    var filter = options.filter;
    var offset = options.offset;
    var limit = options.limit;
    var range = idbKeyRangeFromBoundaries(txn.codec, options.boundaries);
    var direction = descendingToIdbDirection(options.descending);
    var idbIndex = txn.idbTransaction.objectStore(store.name).index(name);

    var paged = filter == null ? idbPagedQuerySupportOrNull(idbIndex) : null;
    if (paged != null) {
      return sdbPagedRowStream(
        paged: paged,
        range: range,
        direction: direction,
        offset: offset,
        limit: limit,
      );
    }

    return idbIndex
        .openCursor(direction: direction, range: range)
        .limitOffsetStream(
          offset: offset,
          limit: limit,
          matcher: filter != null
              ? (cwv) => sdbCursorWithValueMatchesFilter(cwv, filter, txn.codec)
              : null,
        );
  }

  /// Find records.
  Stream<SdbIndexRecordSnapshot<K, V, I>> txnStreamRecordsImpl(
    SdbTransactionImpl txn, {

    required SdbFindOptions<I> options,
  }) {
    return txnStreamRowsImpl(
      txn,
      options: options,
    ).map((row) => _sdbIndexRecordSnapshot(txn.codec, row));
  }

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> txnFindRecordsImpl(
    SdbTransactionImpl txn, {

    required SdbFindOptions<I> options,
  }) async {
    var filter = options.filter;

    if (filter == null) {
      var paged = idbPagedQuerySupportOrNull(
        txn.idbTransaction.objectStore(store.name).index(name),
      );
      if (paged != null) {
        // The implementation can page natively (sql LIMIT/OFFSET), walking
        // the cursor would read every row before the offset. One query here
        // rather than the chunks of txnStreamRowsImpl: the whole result is
        // materialised anyway.
        var rows = await paged.pagedRowList(
          range: idbKeyRangeFromBoundaries(txn.codec, options.boundaries),
          direction: descendingToIdbDirection(options.descending),
          offset: options.offset,
          limit: options.limit,
        );
        return rows
            .map((row) => _sdbIndexRecordSnapshot(txn.codec, row))
            .toList();
      }
    }

    var rows = await txnStreamRowsImpl(txn, options: options).toList();
    return rows.map((row) => _sdbIndexRecordSnapshot(txn.codec, row)).toList();
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
    var range = idbKeyRangeFromBoundaries(txn.codec, boundaries);
    var direction = descendingToIdbDirection(descending);
    var paged = idbPagedQuerySupportOrNull(idbIndex);
    var rows = paged != null
        ? await paged.pagedKeyRowList(
            range: range,
            direction: direction,
            offset: offset,
            limit: limit,
          )
        : await idbIndex
              .openKeyCursor(direction: direction, range: range)
              .toKeyRowList(limit: limit, offset: offset);
    return rows.map((row) {
      var key = row.primaryKey as K;
      var indexKey = indexIdbToSdbKeyValue(txn.codec, row.key);
      return SdbIndexRecordKeyImpl<K, V, I>(this, key, indexKey);
    }).toList();
  }

  /// Count records.
  Future<int> countImpl(
    SdbClient client, {
    required SdbFindOptions<I> options,
  }) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,
    (txn) => txnCountImpl(txn.rawImpl, options: options),
  );

  /// Count records.
  Future<T> dbAutoTxnImpl<T>(
    SdbDatabase db,
    SdbTransactionMode mode,
    Future<T> Function(SdbTransaction txn) fn,
  ) {
    return impl.store.dbAutoTxnImpl(db, mode, fn);
  }

  /// Count records.
  Future<T> clientAutoTxnImpl<T>(
    SdbClient client,
    SdbTransactionMode? mode,
    Future<T> Function(SdbTransaction txn) fn,
  ) {
    return impl.store.clientAutoTxnImpl(
      client,
      mode ?? SdbTransactionMode.readOnly,
      fn,
    );
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
    var count = await idbIndex.count(
      idbKeyRangeFromBoundaries(txn.codec, boundaries),
    );
    if ((offset ?? -1) > 0) {
      count = max(0, count - offset!);
    }
    if ((limit ?? -1) > 0) {
      count = min(count, limit!);
    }

    return count;
  }

  /// Delete records.
  Future<void> deleteImpl(
    SdbClient client, {
    required SdbFindOptions<I> options,
  }) => impl.store.clientAutoTxnImpl(
    client,
    SdbTransactionMode.readWrite,
    (txn) => txnDeleteImpl(txn.rawImpl, options: options),
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
    // A raw cursor delete is not seen by the store change listeners: when
    // there are some, delete record by record so that they are notified.
    var hasChangeListener =
        txn.changesListener?.storeHasChangeListener(store) ?? false;
    if (options.filter != null || hasChangeListener) {
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
    var range = idbKeyRangeFromBoundaries(txn.codec, boundaries);
    var direction = descendingToIdbDirection(descending);

    var paged = idbPagedQuerySupportOrNull(idbIndex);
    if (paged != null) {
      return sdbPagedDelete(
        paged: paged,
        range: range,
        direction: direction,
        offset: offset,
        limit: limit,
        deleteKey: (primaryKey) => store.record(primaryKey as K).delete(txn),
      );
    }

    // Need full cursor for delete
    var stream = idbIndex.openCursor(
      autoAdvance: true,
      direction: direction,
      range: range,
    );
    await streamWithOffsetAndLimit(stream, offset, limit).listen((cursor) {
      cursor.delete();
    }).asFuture<void>();
  }

  /// Iterate records
  ///
  Future<void> txnIterateImpl(
    SdbTransactionImpl txn, {
    required SdbFindOptions<K> options,
    required SdbIndexCursorRowHandler<K, V, I> handler,
  }) {
    var filter = options.filter;
    var offset = options.offset;
    var limit = options.limit;
    var descending = options.descending;
    var boundaries = options.boundaries;
    var codec = txn.codec;
    var idbObjectStore = txn.idbTransaction.objectStore(store.name);
    var idbIndex = idbObjectStore.index(name);
    var range = idbKeyRangeFromBoundaries(codec, boundaries);
    var direction = descendingToIdbDirection(descending);

    var paged = filter == null ? idbPagedQuerySupportOrNull(idbIndex) : null;
    if (paged != null) {
      // The implementation can page natively (sql LIMIT/OFFSET), read the
      // rows chunk by chunk instead of walking the cursor.
      return sdbPagedIterate(
        paged: paged,
        range: range,
        direction: direction,
        offset: offset,
        limit: limit,
        handleRow: (row) => handler(
          SdbIndexCursorRowImpl<K, V, I>.paged(
            key: row.key,
            rawValue: row.value,
            onUpdate: (data) => paged.pagedRowUpdate(row.primaryKey, data),
          ),
        ),
      );
    }

    var cursor = idbIndex.openCursor(direction: direction, range: range);
    var openCursor = SdbIndexOpenCursorImpl<K, V, I>(
      idbStream: cursor,
      handler: handler,
      offset: offset,
      limit: limit,
      filter: filter,
      codec: codec,
    );
    return openCursor.done;
  }

  /// Count records.
  Future<void> clientIterateImpl(
    SdbClient client, {
    required SdbTransactionMode mode,
    required SdbFindOptions<K> options,
    required SdbIndexCursorRowHandler<K, V, I> handler,
  }) => clientAutoTxnImpl(
    client,
    mode,
    (txn) => txnIterateImpl(txn.rawImpl, options: options, handler: handler),
  );
}
