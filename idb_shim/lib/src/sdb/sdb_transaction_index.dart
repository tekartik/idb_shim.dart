import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/src/sdb/sdb_index.dart';
import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/sdb/sdb_schema.dart';
import 'package:meta/meta.dart';

import 'sdb_codec.dart';
import 'sdb_find_options.dart';
import 'sdb_index_cursor.dart';
import 'sdb_index_impl.dart';
import 'sdb_index_record_impl.dart';
import 'sdb_index_record_snapshot.dart';
import 'sdb_index_record_snapshot_impl.dart';
import 'sdb_key_utils.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_impl.dart';
import 'sdb_transaction_store.dart';
import 'sdb_transaction_store_impl.dart';
import 'sdb_types.dart';

/// Transaction store reference.
abstract class SdbTransactionIndexRef<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
> {
  /// Create transaction index reference.
  @protected
  factory SdbTransactionIndexRef({
    required SdbIndexRef<K, V, I> index,
    required SdbTransactionStoreRef<K, V> txnStore,
  }) {
    return _SdbTransactionIndexRefIdb<K, V, I>(ref: index, store: txnStore);
  }

  /// transaction store reference.
  SdbTransactionStoreRef<K, V> get store;

  /// Store reference.
  SdbIndexRef<K, V, I> get ref;

  /// Index name.
  String get name;

  /// Transaction reference.
  SdbTransaction get transaction;

  /// Key Paths.
  SdbKeyPath get keyPath;

  /// Unique
  bool get unique;

  /// Multi entry
  bool get multiEntry;
}

/// Internal interface implemented by every transaction index, idb based or
/// not. The index operations of [SdbIndexRefExtension] go through it.
abstract class SdbTransactionIndexRefInterface<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbTransactionIndexRef<K, V, I> {
  /// First record with this index key.
  Future<SdbIndexRecordSnapshot<K, V, I>?> getRecordImpl(I indexKey);

  /// Primary key of the first record with this index key.
  Future<K?> getKeyImpl(I indexKey);

  /// Primary keys of the records with this index key, in primary key order,
  /// read without a cursor: it can run while a cursor of the same
  /// transaction is being walked (a join does that).
  Future<List<K>> getKeysImpl(I indexKey);

  /// The records with this index key, in primary key order, read without a
  /// cursor like [getKeysImpl].
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> getRecordsImpl(I indexKey);

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> findRecordsImpl({
    required SdbFindOptions<I> options,
  });

  /// Stream records.
  Stream<SdbIndexRecordSnapshot<K, V, I>> streamRecordsImpl({
    required SdbFindOptions<I> options,
  });

  /// Find record keys.
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeysImpl({
    required SdbFindOptions<I> options,
  });

  /// Count records.
  Future<int> countImpl({required SdbFindOptions<I> options});

  /// Delete records.
  Future<void> deleteRecordsImpl({required SdbFindOptions<I> options});

  /// Iterate on records, the boundaries of [options] are index keys (the
  /// options are untyped, the public api types them with the store key).
  Future<void> iterateImpl({
    required SdbFindOptions<SdbKey> options,
    required SdbIndexCursorRowHandler<K, V, I> handler,
  });
}

/// Idb mixin for transaction index ref.
mixin SdbTransactionIndexRefIdbMixin<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbTransactionIndexRef<K, V, I> {
  /// Idb index
  idb.Index get idbIndex;

  @override
  SdbKeyPath get keyPath => idbKeyPathToSdbKeyPath(idbIndex.keyPath);

  @override
  bool get unique => idbIndex.unique;
  @override
  bool get multiEntry => idbIndex.multiEntry;

  @override
  String get name => idbIndex.name;
}

class _SdbTransactionIndexRefIdb<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    with SdbTransactionIndexRefIdbMixin<K, V, I>
    implements SdbTransactionIndexRefInterface<K, V, I> {
  _SdbTransactionIndexRefIdb({required this.ref, required this.store}) {
    idbIndex = storeImpl.idbObjectStore.index(ref.name);
  }
  @override
  late final idb.Index idbIndex;
  @override
  final SdbTransactionStoreRef<K, V> store;
  @override
  final SdbIndexRef<K, V, I> ref;
  @override
  SdbTransaction get transaction => store.transaction;

  SdbTransactionStoreRefImpl<K, V> get storeImpl =>
      store as SdbTransactionStoreRefImpl<K, V>;

  SdbTransactionImpl get _txn => transaction.rawImpl;
  SdbIndexRefImpl<K, V, I> get _refImpl => ref.impl;

  @override
  Future<SdbIndexRecordSnapshot<K, V, I>?> getRecordImpl(I indexKey) =>
      ref.record(indexKey).txnGetImpl(_txn);

  @override
  Future<K?> getKeyImpl(I indexKey) => ref.record(indexKey).txnGetKeyImpl(_txn);

  Future<List<Object>> _idbKeys(I indexKey) async {
    var idbKey = sdbIndexKeyToIdbKey(transaction.codec, indexKey);
    return idbIndex.getAllKeys(idb.KeyRange.only(idbKey));
  }

  @override
  Future<List<K>> getKeysImpl(I indexKey) async =>
      (await _idbKeys(indexKey)).cast<K>();

  @override
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> getRecordsImpl(
    I indexKey,
  ) async {
    var codec = transaction.codec;
    var idbObjectStore = storeImpl.idbObjectStore;
    var records = <SdbIndexRecordSnapshot<K, V, I>>[];
    for (var key in await _idbKeys(indexKey)) {
      var rawValue = await idbObjectStore.getObject(key);
      if (rawValue == null) {
        continue;
      }
      records.add(
        SdbIndexRecordSnapshotImpl<K, V, I>(
          ref,
          key as K,
          codec.decode<V>(rawValue),
          indexKey,
        ),
      );
    }
    return records;
  }

  @override
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> findRecordsImpl({
    required SdbFindOptions<I> options,
  }) => _refImpl.txnFindRecordsImpl(_txn, options: options);

  @override
  Stream<SdbIndexRecordSnapshot<K, V, I>> streamRecordsImpl({
    required SdbFindOptions<I> options,
  }) => _refImpl.txnStreamRecordsImpl(_txn, options: options);

  @override
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeysImpl({
    required SdbFindOptions<I> options,
  }) => _refImpl.txnFindRecordKeysImpl(_txn, options: options);

  @override
  Future<int> countImpl({required SdbFindOptions<I> options}) =>
      _refImpl.txnCountImpl(_txn, options: options);

  @override
  Future<void> deleteRecordsImpl({required SdbFindOptions<I> options}) =>
      _refImpl.txnDeleteImpl(_txn, options: options);

  @override
  Future<void> iterateImpl({
    required SdbFindOptions<SdbKey> options,
    required SdbIndexCursorRowHandler<K, V, I> handler,
  }) => _refImpl.txnIterateImpl(_txn, options: options, handler: handler);
}
