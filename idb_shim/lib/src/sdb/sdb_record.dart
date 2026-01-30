import 'sdb_client.dart';
import 'sdb_record_impl.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// Record ref (or key).
abstract class SdbRecordRef<K extends SdbKey, V extends SdbValue> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Primary key.
  K get key;

  /// Cast if needed.
  SdbRecordRef<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>();
}

/// Store methods.
extension SdbRecordRefExtension<K extends SdbKey, V extends SdbValue>
    on SdbRecordRef<K, V> {
  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> get(SdbClient client) =>
      impl.getImpl(client);

  /// Check if a record exists.
  Future<bool> exists(SdbClient client) => impl.existsImpl(client);

  /// Get a single value, returns null if not found.
  Future<V?> getValue(SdbClient client) =>
      get(client).then((snapshot) => snapshot?.value);

  /// Delete a single record.
  Future<void> delete(SdbClient client) => impl.deleteImpl(client);

  /// Put a single record.
  Future<void> put(SdbClient client, V value) => impl.putImpl(client, value);
}

/// Common extension
extension SdbRecordRefIterableExtension<K extends SdbKey, V extends SdbValue>
    on Iterable<SdbRecordRef<K, V>> {
  /// List of primary keys
  List<K> get keys => map((e) => e.key).toList();
}
