import 'package:idb_shim/sdb.dart';

/// Record key (returns by getKey store methods).
abstract class SdbRecordKey<K extends SdbKey, V extends SdbValue> {
  /// Record ref.
  SdbRecordRef<K, V> get ref;

  /// Cast if needed.
  SdbRecordKey<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>();
}

/// Record snapshot.
abstract class SdbRecordSnapshot<K extends SdbKey, V extends SdbValue>
    implements SdbRecordKey<K, V> {
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
  List<SdbRecordRef<K, V>> get refs => map((e) => e.ref).toList();

  /// List of primary keys
  List<K> get keys => map((e) => e.key).toList();
}

/// Common snapshot extension
extension SdbRecordSnapshotExt<K extends SdbKey, V extends SdbValue>
    on SdbRecordSnapshot<K, V> {}

/// Common key extension
extension SdbRecordKeyExt<K extends SdbKey, V extends SdbValue>
    on SdbRecordKey<K, V> {
  /// Get the record key
  K get key => ref.key;

  /// Get the store
  SdbStoreRef<K, V> get store => ref.store;
}

/// Common extension
extension SdbRecordKeyListExt<K extends SdbKey, V extends SdbValue>
    on Iterable<SdbRecordKey<K, V>> {
  /// List of primary keys
  List<K> get keys => map((e) => e.key).toList();
}
