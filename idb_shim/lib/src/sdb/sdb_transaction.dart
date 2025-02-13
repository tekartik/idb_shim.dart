import 'sdb_client.dart';
import 'sdb_store.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction_impl.dart';
import 'sdb_transaction_store.dart';
import 'sdb_types.dart';

/// SimpleDb transaction.
abstract class SdbTransaction implements SdbClient {}

/// SimpleDb transaction extension.
extension SdbTransactionExtension on SdbTransaction {
  /// transaction store.
  SdbTransactionStoreRef<K, V> store<K extends KeyBase, V extends ValueBase>(
    SdbStoreRef<K, V> store,
  ) => rawImpl.storeImpl<K, V>(store.impl);
}

/// Transaction mode.
enum SdbTransactionMode {
  /// Open in read write mode.
  readWrite,

  /// Open in read only mode.
  readOnly,
}
