import 'sdb_index.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// Index record snapshot.
abstract class SdbIndexRecordSnapshot<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> extends SdbIndexRecordKey<K, V, I> {
  /// Value.
  V get value;
}

/// Index record key.
abstract class SdbIndexRecordKey<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Index reference.
  SdbIndexRef<K, V, I> get index;

  /// Primary key.
  K get key;

  /// Index key.
  I get indexKey;
}

/// Common extension
extension SdbIndexRecordSnapshotListExt<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> on List<SdbIndexRecordSnapshot<K, V, I>> {
  /// List of values
  List<V> get values => map((e) => e.value).toList();
}

/// Common extension
extension SdbIndexRecordKeyListExt<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> on List<SdbIndexRecordKey<K, V, I>> {
  /// List of index keys
  List<I> get indexKeys => map((e) => e.indexKey).toList();

  /// List of primary keys
  List<K> get keys => map((e) => e.key).toList();
}
