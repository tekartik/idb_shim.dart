import 'sdb_client.dart';
import 'sdb_record_impl.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// A reference to a record in a store.
///
/// It contains the store and the key of the record.
abstract class SdbRecordRef<K extends SdbKey, V extends SdbValue> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Primary key.
  K get key;

  /// Cast if needed.
  SdbRecordRef<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>();
}

/// Record reference extension.
extension SdbRecordRefExtension<K extends SdbKey, V extends SdbValue>
    on SdbRecordRef<K, V> {
  /// Get a single record snapshot.
  ///
  /// If the record does not exist, the snapshot will have `exists` set to
  /// `false`.
  Future<SdbRecordSnapshot<K, V>?> get(SdbClient client) =>
      impl.getImpl(client);

  /// Check if a record exists.
  Future<bool> exists(SdbClient client) => impl.existsImpl(client);

  /// Get a single value, returns null if not found.
  Future<V?> getValue(SdbClient client) =>
      get(client).then((snapshot) => snapshot?.value);

  /// Delete a single record.
  Future<void> delete(SdbClient client) => impl.deleteImpl(client);

  /// Put a single record (insert or update).
  Future<void> put(SdbClient client, V value) => impl.putImpl(client, value);
}

/// Record reference list extension.
extension SdbRecordRefIterableExtension<K extends SdbKey, V extends SdbValue>
    on Iterable<SdbRecordRef<K, V>> {
  /// List of primary keys
  List<K> get keys => map((e) => e.key).toList();
}
