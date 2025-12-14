import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/sdb.dart';

import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_index.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_store_impl.dart';

import 'sdb_database_impl.dart';
import 'sdb_index_impl.dart';
import 'sdb_store_impl.dart';

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
  idb.Transaction get _idbTransaction => _sdbOpenTransaction.idbTransaction;
  late final SdbOpenTransactionImpl _sdbOpenTransaction;

  /// Stores.
  final stores = <SdbOpenStoreRefIdb>[];

  /// Open database implementation.
  SdbOpenDatabaseImpl(this.db, idb.Transaction idbTransaction) {
    _sdbOpenTransaction = SdbOpenTransactionImpl(this, idbTransaction);
  }

  /// Create a store.
  /// auto increment is set to true if not set for int keys
  @override
  SdbOpenStoreRef<K, V> createStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store, {
    Object? keyPath,
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

  @override
  void deleteStore(String storeName) {
    db.idbDatabase.deleteObjectStore(storeName);
  }

  /// Add a store.
  SdbOpenStoreRef<K, V> addStoreImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRefImpl<K, V> store, {
    Object? keyPath,
    bool? autoIncrement,
  }) {
    var idbStore = db.idbDatabase.createObjectStore(
      store.name,
      keyPath: keyPath,
      autoIncrement: autoIncrement ?? store.isIntKey,
    );
    var storeOpen = SdbOpenStoreRefIdb<K, V>(
      _sdbOpenTransaction,
      store,
      idbStore,
    );
    stores.add(storeOpen);
    return storeOpen;
  }

  /// Add a store.
  SdbOpenStoreRef<K, V> getStoreImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRefImpl<K, V> store,
  ) {
    var idbStore = _idbTransaction.objectStore(store.name);
    var storeOpen = SdbOpenStoreRefIdb<K, V>(
      _sdbOpenTransaction,
      store,
      idbStore,
    );
    return storeOpen;
  }

  @override
  Iterable<String> get objectStoreNames => db.storeNames;
}

/// Open transaction.
abstract class SdbOpenTransaction implements SdbTransaction {
  /// Open database.
  SdbOpenDatabase get db;
}

/// Open transaction internal extension.
class SdbOpenTransactionImpl implements SdbOpenTransaction {
  /// Database implementation.
  @override
  final SdbOpenDatabaseImpl db;

  /// IDB transaction.
  final idb.Transaction idbTransaction;

  /// Open transaction implementation.
  SdbOpenTransactionImpl(this.db, this.idbTransaction);

  @override
  Iterable<String> get storeNames => idbTransaction.objectStoreNames;
}

/// Open store reference internal extension.
extension SdbOpenStoreRefInternalExtension<K extends SdbKey, V extends SdbValue>
    on SdbOpenStoreRef<K, V> {
  /// Open store reference implementation.
  SdbOpenStoreRefIdb<K, V> get impl => this as SdbOpenStoreRefIdb<K, V>;
}

/// Open store reference implementation.
class SdbOpenStoreRefIdb<K extends SdbKey, V extends SdbValue>
    with SdbTransactionStoreRefImplMixin<K, V>
    implements SdbOpenStoreRef<K, V> {
  /// The open database.
  @override
  final SdbOpenTransaction transaction;

  /// The store.
  @override
  final SdbStoreRefImpl<K, V> store;

  /// The IDB object store.
  @override
  final idb.ObjectStore idbObjectStore;

  /// The indexes.
  final indexes = <SdbOpenIndexRefImpl>[];

  /// Open store reference implementation.
  SdbOpenStoreRefIdb(this.transaction, this.store, this.idbObjectStore);

  /// The name of the store.
  String get name => store.name;

  /// Create an index.
  SdbOpenIndexRef<K, V, I> createIndexImpl<I extends SdbIndexKey>(
    SdbIndexRefImpl<K, V, I> index,
    Object indexKeyPath,
  ) {
    // Fix key path if needed
    var keyPath = idbKeyPathFromAny(indexKeyPath);
    var idbIndex = idbObjectStore.createIndex(index.name, keyPath);
    var indexOpen = SdbOpenIndexRefImpl<K, V, I>(this, index, idbIndex);

    indexes.add(indexOpen);
    return indexOpen;
  }

  @override
  Iterable<String> get indexNames => idbObjectStore.indexNames;

  @override
  void deleteIndex(String indexName) {
    idbObjectStore.deleteIndex(indexName);
  }

  @override
  SdbOpenIndexRef<K, V, I> index<I extends SdbIndexKey>(
    SdbIndexRef<SdbKey, SdbValue, SdbIndexKey> indexRef,
  ) {
    var idbIndex = idbObjectStore.index(name);
    return SdbOpenIndexRefImpl<K, V, I>(
      this,
      indexRef as SdbIndexRefImpl<K, V, I>,
      idbIndex,
    );
  }
}

/// Open index reference implementation.
class SdbOpenIndexRefImpl<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    with SdbTransactionIndexRefIdbMixin<K, V, I>
    implements SdbOpenIndexRef<K, V, I> {
  /// The IDB index.
  @override
  final idb.Index idbIndex;

  /// Open store reference.
  @override
  final SdbOpenStoreRefIdb<K, V> store;

  /// Index reference.
  @override
  final SdbIndexRef<K, V, I> ref;

  /// Open index reference implementation.
  SdbOpenIndexRefImpl(this.store, this.ref, this.idbIndex);

  @override
  SdbOpenTransaction get transaction => store.transaction;
}
