import 'sdb_boundary.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_store_impl.dart';
import 'sdb_types.dart';

/// Transaction store reference.
abstract class SdbTransactionStoreRef<K extends KeyBase, V extends ValueBase> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Transaction reference.
  SdbTransaction get transaction;
}

/// Transaction store actions.
extension SdbTransactionStoreRefExtension<K extends KeyBase,
    V extends ValueBase> on SdbTransactionStoreRef<K, V> {
  SdbTransactionStoreRefImpl<K, V> get _impl =>
      this as SdbTransactionStoreRefImpl<K, V>;

  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> getRecord(K key) => _impl.getRecordImpl(key);

  /// Add.
  Future<K> add(V value) => _impl.addImpl(value);

  /// Put.
  Future<void> put(K? key, V value) => _impl.putImpl(key, value);

  /// Delete.
  Future<void> delete(K key) => _impl.deleteImpl(key);

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecords(
          {SdbBoundaries<K>? boundaries, int? offset, int? limit}) =>
      _impl.findRecordsImpl(
          boundaries: boundaries, offset: offset, limit: limit);

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeys(
          {SdbBoundaries<K>? boundaries, int? offset, int? limit}) =>
      _impl.findRecordKeysImpl(
          boundaries: boundaries, offset: offset, limit: limit);

  /// Count record.
  Future<int> count({SdbBoundaries<K>? boundaries}) =>
      _impl.countImpl(boundaries: boundaries);

  /// Delete records.
  Future<void> deleteRecords(
          {SdbBoundaries<K>? boundaries, int? offset, int? limit}) =>
      _impl.deleteRecordsImpl(
          boundaries: boundaries, offset: offset, limit: limit);

  /// store name.
  String get name => store.name;
}

/// Single store transaction.
abstract class SdbSingleStoreTransaction<K extends KeyBase, V extends ValueBase>
    implements SdbTransaction {
  /// Transaction store reference.
  SdbTransactionStoreRef<K, V> get txnStore;
}

/// Single store transaction extension.
extension SdbSingleStoreTransactionExtension<K extends KeyBase,
    V extends ValueBase> on SdbSingleStoreTransaction<K, V> {
  /// Get a single record.
  Future<SdbRecordSnapshot<K, V>?> getRecord(K key) => impl.getRecordImpl(key);

  /// Add a record
  Future<K> add(V value) => impl.addImpl(value);

  /// Put a record
  Future<void> put(K key, V value) => impl.putImpl(key, value);

  /// Delete a record
  Future<void> delete(K key) => impl.deleteImpl(key);

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecords(
          {SdbBoundaries<K>? boundaries, int? offset, int? limit}) =>
      impl.findRecordsImpl(
          boundaries: boundaries, offset: offset, limit: limit);

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeys(
          {SdbBoundaries<K>? boundaries, int? offset, int? limit}) =>
      impl.findRecordKeysImpl(
          boundaries: boundaries, offset: offset, limit: limit);
}

/// Multi-store transaction.
abstract class SdbMultiStoreTransaction implements SdbTransaction {}

/// Transaction store actions.
extension SdbMultiStoreTransactionExtension on SdbMultiStoreTransaction {
  /// Get a transaction store.
  SdbTransactionStoreRef<K, V> txnStore<K extends KeyBase, V extends ValueBase>(
          SdbStoreRef<K, V> store) =>
      impl.txnStoreImpl<K, V>(store);
}
