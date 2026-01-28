import 'package:idb_shim/sdb.dart';

/// Record snapshot.
abstract class SdbRecordSnapshot<K extends SdbKey, V extends SdbValue>
    extends SdbRecordRef<K, V> {
  /// Value.
  V get value;

  /// Cast if needed
  @override
  SdbRecordSnapshot<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>();
}

/// Fix result type.
V fixResult<V>(Object result) {
  // cast the map if needed
  if (result is Map && result is! SdbModel) {
    result = result.cast<String, Object?>();
  }
  return result as V;
}

/// Common extension
extension SdbRecordSnapshotListExt<K extends SdbKey, V extends SdbValue>
    on List<SdbRecordSnapshot<K, V>> {
  /// List of values
  List<V> get values => map((e) => e.value).toList();

  /// List of refs
  List<SdbRecordRef> get refs => map((e) => e.ref).toList();
}

/// Common extension
extension SdbRecordSnapshotExt<K extends SdbKey, V extends SdbValue>
    on SdbRecordSnapshot<K, V> {
  /// Get the record ref
  SdbRecordRef<K, V> get ref => store.record(key);
}

/// Common extension
extension SdbRecordKeyListExt<K extends SdbKey, V extends SdbValue>
    on Iterable<SdbRecordRef<K, V>> {
  /// List of primary keys
  List<K> get keys => map((e) => e.key).toList();
}
