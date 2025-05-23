import 'package:idb_shim/idb.dart' as idb;

import 'sdb_database_impl.dart';
import 'sdb_index.dart';
import 'sdb_index_impl.dart';
import 'sdb_open.dart';
import 'sdb_store.dart';
import 'sdb_store_impl.dart';
import 'sdb_types.dart';

/// Open database internal extension.
extension SdbOpenDatabaseInternalExtension on SdbOpenDatabase {
  /// Open database implementation.
  SdbOpenDatabaseImpl get impl => this as SdbOpenDatabaseImpl;
}

/// Open database implementation.
class SdbOpenDatabaseImpl implements SdbOpenDatabase {
  /// Database implementation.
  final SdbDatabaseImpl db;

  /// IDB transaction.
  final idb.Transaction idbTransaction;

  /// Stores.
  final stores = <SdbOpenStoreRefIdb>[];

  /// Open database implementation.
  SdbOpenDatabaseImpl(this.db, this.idbTransaction);

  /// Create a store.
  /// auto increment is set to true if not set for int keys
  @override
  SdbOpenStoreRef<K, V> createStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store, {
    String? keyPath,
    bool? autoIncrement,
  }) => impl.addStoreImpl<K, V>(
    store.impl,
    keyPath: keyPath,
    autoIncrement: autoIncrement,
  );

  /// get an existing store.
  @override
  SdbOpenStoreRef<K, V> objectStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
  ) => impl.getStoreImpl<K, V>(store.impl);

  /// Add a store.
  SdbOpenStoreRef<K, V> addStoreImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRefImpl<K, V> store, {
    String? keyPath,
    bool? autoIncrement,
  }) {
    var idbStore = db.idbDatabase.createObjectStore(
      store.name,
      keyPath: keyPath,
      autoIncrement: autoIncrement ?? store.isIntKey,
    );
    var storeOpen = SdbOpenStoreRefIdb<K, V>(this, store, idbStore);
    stores.add(storeOpen);
    return storeOpen;
  }

  /// Add a store.
  SdbOpenStoreRef<K, V> getStoreImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRefImpl<K, V> store,
  ) {
    var idbStore = idbTransaction.objectStore(store.name);
    var storeOpen = SdbOpenStoreRefIdb<K, V>(this, store, idbStore);
    return storeOpen;
  }
}

/// Open store reference internal extension.
extension SdbOpenStoreRefInternalExtension<K extends SdbKey, V extends SdbValue>
    on SdbOpenStoreRef<K, V> {
  /// Open store reference implementation.
  SdbOpenStoreRefIdb<K, V> get impl => this as SdbOpenStoreRefIdb<K, V>;
}

/// Open store reference implementation.
class SdbOpenStoreRefIdb<K extends SdbKey, V extends SdbValue>
    implements SdbOpenStoreRef<K, V> {
  /// The open database.
  final SdbOpenDatabase db;

  /// The store.
  final SdbStoreRefImpl<K, V> store;

  /// The IDB object store.
  final idb.ObjectStore idbObjectStore;

  /// The indexes.
  final indexes = <SdbOpenIndexRefImpl>[];

  /// Open store reference implementation.
  SdbOpenStoreRefIdb(this.db, this.store, this.idbObjectStore);

  /// Create an index.
  @override
  SdbOpenIndexRef<K, V, I> createIndex<I extends SdbIndexKey>(
    SdbIndex1Ref<K, V, I> index,
    String indexKeyPath,
  ) => impl.createIndexImpl<I>(index.impl, indexKeyPath);

  /// Create an index on 2 fields.
  @override
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
  @override
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
  @override
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

  /// The name of the store.
  String get name => store.name;

  /// Create an index.
  SdbOpenIndexRef<K, V, I> createIndexImpl<I extends SdbIndexKey>(
    SdbIndexRefImpl<K, V, I> index,
    Object indexKeyPath,
  ) {
    var idbIndex = idbObjectStore.createIndex(index.name, indexKeyPath);
    var indexOpen = SdbOpenIndexRefImpl<K, V, I>(this, index, idbIndex);

    indexes.add(indexOpen);
    return indexOpen;
  }
}

/// Open index reference implementation.
class SdbOpenIndexRefImpl<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbOpenIndexRef<K, V, I> {
  /// The IDB index.
  final idb.Index idbIndex;

  /// Open store reference.
  final SdbOpenStoreRefIdb store;

  /// Index reference.
  final SdbIndexRef<K, V, I> index;

  /// Open index reference implementation.
  SdbOpenIndexRefImpl(this.store, this.index, this.idbIndex);
}
