import 'sdb_index.dart';
import 'sdb_index_impl.dart';
import 'sdb_open_impl.dart';
import 'sdb_store.dart';
import 'sdb_store_impl.dart';
import 'sdb_types.dart';

/// Database during open.
abstract class SdbOpenDatabase {}

/// Store during open.
abstract class SdbOpenStoreRef<K extends KeyBase, V extends ValueBase> {}

/// Index during open.
abstract class SdbOpenIndexRef<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> {}

/// Database action during open.
extension SdbOpenDatabaseExtension on SdbOpenDatabase {
  /// Create a store.
  SdbOpenStoreRef<K, V> createStore<K extends KeyBase, V extends ValueBase>(
          SdbStoreRef<K, V> store) =>
      impl.addStoreImpl<K, V>(store.impl);

  /// get an existing store.
  SdbOpenStoreRef<K, V> objectStore<K extends KeyBase, V extends ValueBase>(
          SdbStoreRef<K, V> store) =>
      impl.getStoreImpl<K, V>(store.impl);
}

/// Store action during open.
extension SdbOpenStoreRefExtension<K extends KeyBase, V extends ValueBase>
    on SdbOpenStoreRef<K, V> {
  /// Create an index.
  SdbOpenIndexRef<K, V, I> createIndex<I extends IndexBase>(
          SdbIndexRef<K, V, I> index, String indexKeyPath) =>
      impl.createIndexImpl<I>(index.impl, indexKeyPath);
}
