import 'package:idb_shim/sdb.dart';

import 'import_idb.dart';

/// Record snapshot implementation.
class SdbRecordSnapshotImpl<K extends SdbKey, V extends SdbValue>
    implements SdbRecordSnapshot<K, V> {
  @override
  final SdbRecordRef<K, V> ref;
  @override
  final V value;

  /// Record snapshot implementation.
  SdbRecordSnapshotImpl(this.ref, this.value);

  @override
  String toString() => 'Record($ref, ${logTruncateAny(value)}';

  @override
  SdbRecordSnapshot<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>() {
    if (this is SdbRecordSnapshot<RK, RV>) {
      return this as SdbRecordSnapshot<RK, RV>;
    }
    return SdbRecordSnapshotImpl<RK, RV>(ref.cast<RK, RV>(), value as RV);
  }
}

/// Record key implementation.
class SdbRecordKeyImpl<K extends SdbKey, V extends SdbValue>
    implements SdbRecordKey<K, V> {
  @override
  final SdbRecordRef<K, V> ref;

  /// Record key implementation.
  SdbRecordKeyImpl(this.ref);

  @override
  String toString() => 'RecordKey($ref)';

  @override
  SdbRecordKey<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>() {
    if (this is SdbRecordKey<RK, RV>) {
      return this as SdbRecordKey<RK, RV>;
    }
    return SdbRecordKeyImpl(ref.cast<RK, RV>());
  }
}
