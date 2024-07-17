import 'sdb_client.dart';
import 'sdb_record_impl.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// Record reference.
abstract class SdbRecordRef<K extends KeyBase, V extends ValueBase> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Primary key.
  K get key;
}

/// Store methods.
extension SdbRecordRefExtension<K extends KeyBase, V extends ValueBase>
    on SdbRecordRef<K, V> {
  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> get(SdbClient client) =>
      impl.getImpl(client);

  /// Get a single value, returns null if not found.
  Future<V?> getValue(SdbClient client) =>
      get(client).then((snapshot) => snapshot?.value);

  /// Delete a single record.
  Future<void> delete(SdbClient client) => impl.deleteImpl(client);

  /// Put a single record.
  Future<void> put(SdbClient client, V value) => impl.putImpl(client, value);
}
