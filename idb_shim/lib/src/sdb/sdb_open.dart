import 'package:idb_shim/sdb.dart';

import 'sdb_index_impl.dart';
import 'sdb_open_impl.dart';
// ignore: unused_import
import 'sdb_store_impl.dart';

/// Database during open.
abstract class SdbOpenDatabase {
  /// Create a store.
  /// auto increment is set to true if not set for int keys
  SdbOpenStoreRef<K, V> createStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store, {

    /// Only allow a single String keyPath, use autoIncrement and add indexes for more complex keyPaths
    String? keyPath,
    bool? autoIncrement,
  });

  /// get an existing store.
  SdbOpenStoreRef<K, V> objectStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
  );

  ///
  /// list of the names of the object stores currently in the connected database
  ///
  Iterable<String> get objectStoreNames;

  /// Delete a store.
  void deleteStore(String storeName);
}

/// Default mixin.
mixin SdbOpenDatabaseDefaultMixin implements SdbOpenDatabase {
  @override
  SdbOpenStoreRef<K, V> createStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store, {
    Object? keyPath,
    bool? autoIncrement,
  }) {
    throw UnimplementedError('SdbOpenDatabase.createStore');
  }

  @override
  SdbOpenStoreRef<K, V> objectStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
  ) {
    throw UnimplementedError('SdbOpenDatabase.objectStore');
  }
}

/// Store during open.
abstract class SdbOpenStoreRef<K extends SdbKey, V extends SdbValue>
    implements SdbTransactionStoreRef<K, V> {
  /// Delete an index.
  void deleteIndex(String indexName);
}

/// Default open store ref mixin.
mixin SdbOpenStoreRefDefaultMixin<K extends SdbKey, V extends SdbValue>
    implements SdbOpenStoreRef<K, V> {}

/// Index during open.
abstract class SdbOpenIndexRef<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbTransactionIndexRef<K, V, I> {}

/// Database action during open.
extension SdbOpenDatabaseExtension on SdbOpenDatabase {}

/// Store action during open.
extension SdbOpenStoreRefExtension<K extends SdbKey, V extends SdbValue>
    on SdbOpenStoreRef<K, V> {
  /// Create an index.
  SdbOpenIndexRef<K, V, I> createIndex<I extends SdbIndexKey>(
    SdbIndexRef<K, V, I> index,

    /// Can be String or `List<String>` or SdbKeyPath
    Object indexKeyPath,
  ) => impl.createIndexImpl<I>(index.impl, indexKeyPath);

  /// Create an index.
  SdbOpenIndexRef<K, V, I> createIndex1<I extends SdbIndexKey>(
    SdbIndex1Ref<K, V, I> index,
    String indexKeyPath,
  ) => impl.createIndexImpl<I>(index.impl, indexKeyPath);

  /// Create an index on 2 fields.
  SdbOpenIndexRef<K, V, (I1, I2)>
  createIndex2<I1 extends SdbIndexKey, I2 extends SdbIndexKey>(
    SdbIndex2Ref<K, V, I1, I2> index,
    String indexKeyPath1,
    String indexKeyPath2,
  ) => impl.createIndexImpl<(I1, I2)>(index.impl, [
    indexKeyPath1,
    indexKeyPath2,
  ]);

  /// Create an index on 3 fields.
  SdbOpenIndexRef<K, V, (I1, I2, I3)> createIndex3<
    I1 extends SdbIndexKey,
    I2 extends SdbIndexKey,
    I3 extends SdbIndexKey
  >(
    SdbIndex3Ref<K, V, I1, I2, I3> index,
    String indexKeyPath1,
    String indexKeyPath2,
    String indexKeyPath3,
  ) => impl.createIndexImpl<(I1, I2, I3)>(index.impl, [
    indexKeyPath1,
    indexKeyPath2,
    indexKeyPath3,
  ]);

  /// Create an index on 4 fields.
  SdbOpenIndexRef<K, V, (I1, I2, I3, I4)> createIndex4<
    I1 extends SdbIndexKey,
    I2 extends SdbIndexKey,
    I3 extends SdbIndexKey,
    I4 extends SdbIndexKey
  >(
    SdbIndex4Ref<K, V, I1, I2, I3, I4> index,
    String indexKeyPath1,
    String indexKeyPath2,
    String indexKeyPath3,
    String indexKeyPath4,
  ) => impl.createIndexImpl<(I1, I2, I3, I4)>(index.impl, [
    indexKeyPath1,
    indexKeyPath2,
    indexKeyPath3,
    indexKeyPath4,
  ]);
}
