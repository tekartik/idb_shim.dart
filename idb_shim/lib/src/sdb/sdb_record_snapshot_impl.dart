import 'import_idb.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_store_impl.dart';
import 'sdb_types.dart';

/// Record snapshot implementation.
class SdbRecordSnapshotImpl<K extends KeyBase, V extends ValueBase>
    extends SdbRecordKeyImpl<K, V> implements SdbRecordSnapshot<K, V> {
  @override
  final V value;

  /// Record snapshot implementation.
  SdbRecordSnapshotImpl(super.store, super.key, this.value);

  @override
  String toString() => 'Record(${store.name}, $key, ${logTruncateAny(value)}';
}

/// Record key implementation.
class SdbRecordKeyImpl<K extends KeyBase, V extends ValueBase>
    implements SdbRecordKey<K, V> {
  @override
  final SdbStoreRefImpl<K, V> store;
  @override
  final K key;

  /// Record key implementation.
  SdbRecordKeyImpl(this.store, this.key);

  @override
  String toString() => 'RecordKey(${store.name}, $key)';
}
