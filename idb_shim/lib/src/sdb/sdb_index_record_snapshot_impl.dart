import 'import_idb.dart';
import 'sdb_index_impl.dart';
import 'sdb_index_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// Index record snapshot implementation.
class SdbIndexRecordSnapshotImpl<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> implements SdbIndexRecordSnapshot<K, V, I> {
  /// Index reference.
  @override
  final SdbIndexRefImpl<K, V, I> index;

  @override
  final K key;

  @override
  final I indexKey;

  @override
  final V value;

  /// Index record snapshot implementation.
  SdbIndexRecordSnapshotImpl(this.index, this.key, this.value, this.indexKey);

  @override
  String toString() =>
      'IndexRecord(${logTruncateAny(key)}, ${logTruncateAny(indexKey)}, ${logTruncateAny(value)}';

  @override
  SdbStoreRef<K, V> get store => index.store;
}
