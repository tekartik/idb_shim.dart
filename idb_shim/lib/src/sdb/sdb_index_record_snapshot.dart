import 'sdb_index.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// Index record snapshot.
abstract class SdbIndexRecordSnapshot<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Index reference.
  SdbIndexRef<K, V, I> get index;

  /// Primary key.
  K get key;

  /// Index key.
  I get indexKey;

  /// Value.
  V get value;
}
