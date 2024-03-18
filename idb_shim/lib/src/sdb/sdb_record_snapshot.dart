import 'sdb_store.dart';
import 'sdb_types.dart';

/// Record snapshot.
abstract class SdbRecordSnapshot<K extends KeyBase, V extends ValueBase> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Primary key.
  K get key;

  /// Value.
  V get value;
}

/// Fix result type.
V fixResult<V>(Object result) {
  // cast the map if needed
  if (result is Map && result is! SdbModel) {
    result = result.cast<String, Object?>();
  }
  return result as V;
}
