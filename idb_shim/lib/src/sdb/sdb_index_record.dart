import 'sdb_client.dart';
import 'sdb_index.dart';
import 'sdb_index_record_impl.dart';
import 'sdb_index_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// Index record reference.
abstract class SdbIndexRecordRef<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
> {
  /// Index reference.
  SdbIndexRef<K, V, I> get index;

  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Get index key.
  I get indexKey;
}

/// Index record reference extension.
extension SdbIndexRecordRefExtension<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndexRecordRef<K, V, I> {
  /// Get a single record.
  Future<SdbIndexRecordSnapshot<K, V, I>?> get(SdbClient client) =>
      impl.getImpl(client);
}
