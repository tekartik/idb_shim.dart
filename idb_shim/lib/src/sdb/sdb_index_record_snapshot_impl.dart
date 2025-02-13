import 'import_idb.dart';
import 'sdb_index_impl.dart';
import 'sdb_index_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// Index record snapshot implementation.
class SdbIndexRecordSnapshotImpl<
  K extends KeyBase,
  V extends ValueBase,
  I extends IndexBase
>
    extends SdbIndexRecordKeyImpl<K, V, I>
    implements SdbIndexRecordSnapshot<K, V, I> {
  @override
  final V value;

  /// Index record snapshot implementation.
  SdbIndexRecordSnapshotImpl(
    super.index,
    super.key,
    this.value,
    super.indexKey,
  );

  @override
  String toString() =>
      'IndexRecord(${logTruncateAny(key)}, ${logTruncateAny(indexKey)}, ${logTruncateAny(value)}';

  @override
  SdbStoreRef<K, V> get store => index.store;
}

/// Index record snapshot implementation.
class SdbIndexRecordKeyImpl<
  K extends KeyBase,
  V extends ValueBase,
  I extends IndexBase
>
    implements SdbIndexRecordKey<K, V, I> {
  /// Index reference.
  @override
  final SdbIndexRefImpl<K, V, I> index;

  @override
  final K key;

  @override
  final I indexKey;

  /// Index record snapshot implementation.
  SdbIndexRecordKeyImpl(this.index, this.key, this.indexKey);

  @override
  String toString() =>
      'IndexRecordKey(${logTruncateAny(key)}, ${logTruncateAny(indexKey)}}';

  @override
  SdbStoreRef<K, V> get store => index.store;
}
