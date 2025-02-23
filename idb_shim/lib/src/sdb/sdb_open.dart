import 'sdb_index.dart';
import 'sdb_index_impl.dart';
import 'sdb_open_impl.dart';
import 'sdb_store.dart';
// ignore: unused_import
import 'sdb_store_impl.dart';
import 'sdb_types.dart';

/// Database during open.
abstract class SdbOpenDatabase {
  /// Create a store.
  /// auto increment is set to true if not set for int keys
  SdbOpenStoreRef<K, V> createStore<K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store, {
    String? keyPath,
    bool? autoIncrement,
  });

  /// get an existing store.
  SdbOpenStoreRef<K, V> objectStore<K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store,
  );
}

/// Default mixin.
mixin SdbOpenDatabaseDefaultMixin implements SdbOpenDatabase {
  @override
  SdbOpenStoreRef<K, V> createStore<K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store, {
    String? keyPath,
    bool? autoIncrement,
  }) {
    throw UnimplementedError('SdbOpenDatabase.createStore');
  }

  @override
  SdbOpenStoreRef<K, V> objectStore<K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store,
  ) {
    throw UnimplementedError('SdbOpenDatabase.objectStore');
  }
}

/// Store during open.
abstract class SdbOpenStoreRef<K extends KeyBase, V extends ValueBase> {
  /// Create an index.
  SdbOpenIndexRef<K, V, I> createIndex<I extends IndexBase>(
    SdbIndex1Ref<K, V, I> index,
    String indexKeyPath,
  ) => impl.createIndexImpl<I>(index.impl, indexKeyPath);

  /// Create an index on 2 fields.
  SdbOpenIndexRef<K, V, (I1, I2)>
  createIndex2<I1 extends IndexBase, I2 extends IndexBase>(
    SdbIndex2Ref<K, V, I1, I2> index,
    String indexKeyPath1,
    String indexKeyPath2,
  ) => impl.createIndexImpl<(I1, I2)>(index.impl, [
    indexKeyPath1,
    indexKeyPath2,
  ]);

  /// Create an index on 3 fields.
  SdbOpenIndexRef<K, V, (I1, I2, I3)> createIndex3<
    I1 extends IndexBase,
    I2 extends IndexBase,
    I3 extends IndexBase
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
    I1 extends IndexBase,
    I2 extends IndexBase,
    I3 extends IndexBase,
    I4 extends IndexBase
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

/// Default open store ref mixin.
mixin SdbOpenStoreRefDefaultMixin<K extends KeyBase, V extends ValueBase>
    implements SdbOpenStoreRef<K, V> {
  @override
  SdbOpenIndexRef<K, V, I> createIndex<I extends IndexBase>(
    SdbIndex1Ref<K, V, I> index,
    String indexKeyPath,
  ) {
    // TODO: implement createIndex
    throw UnimplementedError();
  }

  @override
  SdbOpenIndexRef<K, V, (I1, I2)>
  createIndex2<I1 extends IndexBase, I2 extends IndexBase>(
    SdbIndex2Ref<K, V, I1, I2> index,
    String indexKeyPath1,
    String indexKeyPath2,
  ) {
    // TODO: implement createIndex2
    throw UnimplementedError();
  }

  @override
  SdbOpenIndexRef<K, V, (I1, I2, I3)> createIndex3<
    I1 extends IndexBase,
    I2 extends IndexBase,
    I3 extends IndexBase
  >(
    SdbIndex3Ref<K, V, I1, I2, I3> index,
    String indexKeyPath1,
    String indexKeyPath2,
    String indexKeyPath3,
  ) {
    // TODO: implement createIndex3
    throw UnimplementedError();
  }

  @override
  SdbOpenIndexRef<K, V, (I1, I2, I3, I4)> createIndex4<
    I1 extends IndexBase,
    I2 extends IndexBase,
    I3 extends IndexBase,
    I4 extends IndexBase
  >(
    SdbIndex4Ref<K, V, I1, I2, I3, I4> index,
    String indexKeyPath1,
    String indexKeyPath2,
    String indexKeyPath3,
    String indexKeyPath4,
  ) {
    // TODO: implement createIndex4
    throw UnimplementedError();
  }
}

/// Index during open.
abstract class SdbOpenIndexRef<
  K extends KeyBase,
  V extends ValueBase,
  I extends IndexBase
> {}

/// Database action during open.
extension SdbOpenDatabaseExtension on SdbOpenDatabase {}

/// Store action during open.
extension SdbOpenStoreRefExtension<K extends KeyBase, V extends ValueBase>
    on SdbOpenStoreRef<K, V> {}
