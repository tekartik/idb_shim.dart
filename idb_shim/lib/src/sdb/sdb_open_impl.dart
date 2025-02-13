import 'package:idb_shim/idb.dart' as idb;

import 'sdb_database_impl.dart';
import 'sdb_index.dart';
import 'sdb_index_impl.dart';
import 'sdb_open.dart';
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
  final stores = <SdbOpenStoreRefImpl>[];

  /// Open database implementation.
  SdbOpenDatabaseImpl(this.db, this.idbTransaction);

  /// Add a store.
  SdbOpenStoreRef<K, V> addStoreImpl<K extends KeyBase, V extends ValueBase>(
    SdbStoreRefImpl<K, V> store, {
    String? keyPath,
    bool? autoIncrement,
  }) {
    var idbStore = db.idbDatabase.createObjectStore(
      store.name,
      keyPath: keyPath,
      autoIncrement: autoIncrement ?? store.isIntKey,
    );
    var storeOpen = SdbOpenStoreRefImpl<K, V>(this, store, idbStore);
    stores.add(storeOpen);
    return storeOpen;
  }

  /// Add a store.
  SdbOpenStoreRef<K, V> getStoreImpl<K extends KeyBase, V extends ValueBase>(
    SdbStoreRefImpl<K, V> store,
  ) {
    var idbStore = idbTransaction.objectStore(store.name);
    var storeOpen = SdbOpenStoreRefImpl<K, V>(this, store, idbStore);
    return storeOpen;
  }
}

/// Open store reference internal extension.
extension SdbOpenStoreRefInternalExtension<
  K extends KeyBase,
  V extends ValueBase
>
    on SdbOpenStoreRef<K, V> {
  /// Open store reference implementation.
  SdbOpenStoreRefImpl<K, V> get impl => this as SdbOpenStoreRefImpl<K, V>;
}

/// Open store reference implementation.
class SdbOpenStoreRefImpl<K extends KeyBase, V extends ValueBase>
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
  SdbOpenStoreRefImpl(this.db, this.store, this.idbObjectStore);

  /// The name of the store.
  String get name => store.name;

  /// Create an index.
  SdbOpenIndexRef<K, V, I> createIndexImpl<I extends IndexBase>(
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
  K extends KeyBase,
  V extends ValueBase,
  I extends IndexBase
>
    implements SdbOpenIndexRef<K, V, I> {
  /// The IDB index.
  final idb.Index idbIndex;

  /// Open store reference.
  final SdbOpenStoreRefImpl store;

  /// Index reference.
  final SdbIndexRef<K, V, I> index;

  /// Open index reference implementation.
  SdbOpenIndexRefImpl(this.store, this.index, this.idbIndex);
}
