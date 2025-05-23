import 'sdb_store.dart';
import 'sdb_types.dart';

/// Record snapshot.
abstract class SdbRecordSnapshot<K extends SdbKey, V extends SdbValue>
    extends SdbRecordKey<K, V> {
  /// Value.
  V get value;
}

/// Record snapshot.
abstract class SdbRecordKey<K extends SdbKey, V extends SdbValue> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Primary key.
  K get key;
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
}

/// Common extension
extension SdbRecordKeyListExt<K extends SdbKey, V extends SdbValue>
    on List<SdbRecordKey<K, V>> {
  /// List of primary keys
  List<K> get keys => map((e) => e.key).toList();
}
