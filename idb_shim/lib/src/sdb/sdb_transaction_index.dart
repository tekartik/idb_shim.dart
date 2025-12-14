import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/src/sdb/sdb_index.dart';
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
    return _SdbTransactionIndexRef<K, V, I>(ref: index, store: txnStore);
  }

  /// Transaction reference.
  SdbTransaction get transaction;

  /// Key Paths.
  List<String> get keyPaths;
}

class _SdbTransactionIndexRef<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbTransactionIndexRef<K, V, I> {
  late final idb.Index idbIndex;
  @override
  final SdbTransactionStoreRef<K, V> store;
  @override
  final SdbIndexRef<K, V, I> ref;
  @override
  SdbTransaction get transaction => store.transaction;

  SdbTransactionStoreRefImpl<K, V> get storeImpl =>
      store as SdbTransactionStoreRefImpl<K, V>;
  _SdbTransactionIndexRef({required this.ref, required this.store}) {
    idbIndex = storeImpl.idbObjectStore.index(ref.name);
  }

  @override
  List<String> get keyPaths {
    var keyPath = idbIndex.keyPath;
    if (keyPath is String) {
      return [keyPath];
    } else if (keyPath is List) {
      return List<String>.from(keyPath);
    } else {
      throw StateError('Invalid keyPath type: ${keyPath.runtimeType}');
    }
  }
}
