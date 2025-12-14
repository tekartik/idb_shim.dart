import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/src/sdb/sdb_index.dart';
import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/sdb/sdb_schema.dart';
import 'package:meta/meta.dart';

import 'sdb_transaction.dart';
import 'sdb_transaction_store.dart';
import 'sdb_transaction_store_impl.dart';
import 'sdb_types.dart';

/// Transaction store reference.
abstract class SdbTransactionIndexRef<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
> {
  /// transaction store reference.
  SdbTransactionStoreRef<K, V> get store;

  /// Store reference.
  SdbIndexRef<K, V, I> get ref;

  /// Create transaction index reference.
  @protected
  factory SdbTransactionIndexRef({
    required SdbIndexRef<K, V, I> index,
    required SdbTransactionStoreRef<K, V> txnStore,
  }) {
    return _SdbTransactionIndexRefIdb<K, V, I>(ref: index, store: txnStore);
  }

  /// Transaction reference.
  SdbTransaction get transaction;

  /// Key Paths.
  SdbKeyPath get keyPath;

  /// Unique
  bool get unique;

  /// Multi entry
  bool get multiEntry;
}

/// Idb mixin for transaction index ref.
mixin SdbTransactionIndexRefIdbMixin<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbTransactionIndexRef<K, V, I> {
  /// Idb index
  idb.Index get idbIndex;

  @override
  SdbKeyPath get keyPath => idbKeyPathToSdbKeyPath(idbIndex.keyPath);

  @override
  bool get unique => idbIndex.unique;
  @override
  bool get multiEntry => idbIndex.multiEntry;
}

class _SdbTransactionIndexRefIdb<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    with SdbTransactionIndexRefIdbMixin<K, V, I>
    implements SdbTransactionIndexRef<K, V, I> {
  @override
  late final idb.Index idbIndex;
  @override
  final SdbTransactionStoreRef<K, V> store;
  @override
  final SdbIndexRef<K, V, I> ref;
  @override
  SdbTransaction get transaction => store.transaction;

  SdbTransactionStoreRefImpl<K, V> get storeImpl =>
      store as SdbTransactionStoreRefImpl<K, V>;
  _SdbTransactionIndexRefIdb({required this.ref, required this.store}) {
    idbIndex = storeImpl.idbObjectStore.index(ref.name);
  }
}
