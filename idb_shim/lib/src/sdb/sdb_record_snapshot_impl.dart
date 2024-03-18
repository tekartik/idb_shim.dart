import 'import_idb.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_store_impl.dart';
import 'sdb_types.dart';

/// Record snapshot implementation.
class SdbRecordSnapshotImpl<K extends KeyBase, V extends ValueBase>
    implements SdbRecordSnapshot<K, V> {
  @override
  final SdbStoreRefImpl<K, V> store;
  @override
  final K key;

  @override
  final V value;

  /// Record snapshot implementation.
  SdbRecordSnapshotImpl(this.store, this.key, this.value);

  @override
  String toString() => 'Record($key, ${logTruncateAny(value)}';
}
