import 'dart:async';
import 'dart:math';

import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/sdb/sdb_filter_impl.dart';
import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/sdb/sdb_schema.dart';
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
  /// Create store schema, keyPath is String, a `List<String>` or SdbKeyPath
  @override
  SdbIndexSchema indexSchema({required Object keyPath, bool? unique}) {
    var single = sdbKeySinglePathFromAny(keyPath);
    return SdbIndexSchema(
      this,
      SdbKeyPath.single(sdbKeyPath<I>(single.keyPath)),
      unique: unique ?? false,
    );
  }

  /// Convert idb key to index key.
  @override
  I indexIdbToSdbKeyValue(Object key) {
    return idbToSdbSimpleKeyValue<I>(key);
  }

  /// Index on 1 field.
  SdbIndex1RefImpl(super.store, super.name) {
    sdbCheckIndexKeyType<I>();
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
  (I1, I2) indexIdbToSdbKeyValue(Object key) {
    var list = key as List;
    return (
      idbToSdbSimpleKeyValue<I1>(list[0]),
      idbToSdbSimpleKeyValue<I2>(list[1]),
    );
  }

  @override
  SdbIndexSchema indexSchema({required Object keyPath, bool? unique}) {
    var multi = sdbKeyMultiPathFromAny(keyPath);
    return SdbIndexSchema(
      this,
      SdbKeyPath.multi([
        sdbKeyPath<I1>(multi.keyPaths[0]),
        sdbKeyPath<I2>(multi.keyPaths[1]),
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
        sdbKeyPath<I1>(multi.keyPaths[0]),
        sdbKeyPath<I2>(multi.keyPaths[1]),
        sdbKeyPath<I3>(multi.keyPaths[2]),
      ]),
      unique: unique ?? false,
    );
  }

  @override
  (I1, I2, I3) indexIdbToSdbKeyValue(Object key) {
    var list = key as List;
    return (
      idbToSdbSimpleKeyValue<I1>(list[0]),
      idbToSdbSimpleKeyValue<I2>(list[1]),
      idbToSdbSimpleKeyValue<I3>(list[2]),
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
        sdbKeyPath<I1>(multi.keyPaths[0]),
        sdbKeyPath<I2>(multi.keyPaths[1]),
        sdbKeyPath<I3>(multi.keyPaths[2]),
        sdbKeyPath<I4>(multi.keyPaths[3]),
      ]),
      unique: unique ?? false,
    );
  }

  @override
  (I1, I2, I3, I4) indexIdbToSdbKeyValue(Object key) {
    var list = key as List;
    return (
      idbToSdbSimpleKeyValue<I1>(list[0]),
      idbToSdbSimpleKeyValue<I2>(list[1]),
      idbToSdbSimpleKeyValue<I3>(list[2]),
      idbToSdbSimpleKeyValue<I4>(list[3]),
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
  /// Convert idb key to index key.
  I indexIdbToSdbKeyValue(Object key);

  /// Index schema to implement
  SdbIndexSchema indexSchema({required Object keyPath, bool? unique});
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
    idb.CursorRow row,
  ) {
    var key = row.primaryKey as K;
    var indexKey = indexIdbToSdbKeyValue(row.key);
    var value = idbToSdbValue(row.value) as V;
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
      var indexKey = indexIdbToSdbKeyValue(row.key);
      return SdbIndexRecordKeyImpl<K, V, I>(this, key, indexKey);
    }).toList();
  }

  /// Count records.
  Future<int> countImpl(
    SdbClient client, {
    required SdbFindOptions<I> options,
  }) => impl.store.clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,
    (txn) => txnCountImpl(txn.rawImpl, options: options),
  );

  /// Count records.
  Future<T> dbAutoTxnImpl<T>(
    SdbDatabase db,
    Future<T> Function(SdbTransaction txn) fn,
  ) {
    return db.inStoreTransaction(store, SdbTransactionMode.readOnly, (txn) {
      return fn(txn.rawImpl);
    });
  }

  /// Count records.
  Future<T> clientAutoTxnImpl<T>(
    SdbClient client,
    Future<T> Function(SdbTransaction txn) fn,
  ) {
    if (client is SdbDatabase) {
      return dbAutoTxnImpl<T>(client, fn);
    } else if (client is SdbTransactionImpl) {
      return fn(client);
    } else {
      throw ArgumentError('Invalid client type: ${client.runtimeType}');
    }
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
