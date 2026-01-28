import 'package:idb_shim/sdb.dart';

import 'import_idb.dart';

/// Record snapshot implementation.
class SdbRecordSnapshotImpl<K extends SdbKey, V extends SdbValue>
    extends SdbRecordKeyImpl<K, V>
    implements SdbRecordSnapshot<K, V> {
  @override
  final V value;

  /// Record snapshot implementation.
  SdbRecordSnapshotImpl(super.store, super.key, this.value);

  @override
  String toString() => 'Record(${store.name}, $key, ${logTruncateAny(value)}';

  @override
  SdbRecordSnapshot<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>() {
    if (this is SdbRecordSnapshot<RK, RV>) {
      return this as SdbRecordSnapshot<RK, RV>;
    }
    return SdbRecordSnapshotImpl<RK, RV>(
      store.cast<RK, RV>(),
      key as RK,
      value as RV,
    );
  }
}

/// Record key implementation.
class SdbRecordKeyImpl<K extends SdbKey, V extends SdbValue>
    implements SdbRecordRef<K, V> {
  @override
  final SdbStoreRef<K, V> store;
  @override
  final K key;

  /// Record key implementation.
  SdbRecordKeyImpl(this.store, this.key);

  @override
  String toString() => 'RecordKey(${store.name}, $key)';

  @override
  SdbRecordRef<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>() {
    return store.cast<RK, RV>().record(key as RK);
  }
}
