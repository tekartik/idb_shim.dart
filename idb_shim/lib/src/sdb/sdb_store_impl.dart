import 'package:idb_shim/src/sdb/sdb_client_impl.dart';

import 'sdb_boundary.dart';
import 'sdb_client.dart';
import 'sdb_database.dart';
import 'sdb_database_impl.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_transaction.dart';
import 'sdb_transaction_impl.dart';
import 'sdb_transaction_store.dart';
import 'sdb_types.dart';

/// Store reference internal extension.
extension SdbStoreRefInternalExtension<K extends KeyBase, V extends ValueBase>
    on SdbStoreRef<K, V> {
  /// Store reference implementation.
  SdbStoreRefImpl<K, V> get impl => this as SdbStoreRefImpl<K, V>;
}

/// Store reference implementation.
class SdbStoreRefImpl<K extends KeyBase, V extends ValueBase>
    implements SdbStoreRef<K, V> {
  @override
  final String name;

  /// Store reference implementation.
  SdbStoreRefImpl(this.name) {
    if (!(K == int || K == String)) {
      throw ArgumentError('K type $K must be int or String');
    }
  }

  /// True if the key is an int.
  bool get isIntKey => K == int;

  @override
  String toString() => 'Store($name)';

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is SdbStoreRef) {
      return name == other.name;
    }
    return false;
  }

  /// Get a single record.
  Future<K> addImpl(SdbClient client, V value) => client.handleDbOrTxn(
      (db) => dbAddImpl(db, value), (txn) => txnAddImpl(txn.rawImpl, value));

  /// Get a single record.
  Future<K> dbAddImpl(SdbDatabaseImpl db, V value) {
    return db.inStoreTransactionImpl<K, K, V>(
        this, SdbTransactionMode.readWrite, (txn) {
      return txn.add(value);
    });
  }

  /// Get a single record.
  Future<K> txnAddImpl(SdbTransactionImpl txn, V value) {
    return txn.storeImpl(this).add(value);
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl(SdbClient client,
          {SdbBoundaries<K>? boundaries}) =>
      client.handleDbOrTxn(
          (db) => dbFindRecordsImpl(db, boundaries: boundaries),
          (txn) => txnFindRecordsImpl(txn, boundaries: boundaries));

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> dbFindRecordsImpl(SdbDatabase db,
      {SdbBoundaries<K>? boundaries}) {
    return db.inStoreTransaction(this, SdbTransactionMode.readOnly, (txn) {
      return txn.findRecords(boundaries: boundaries);
    });
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> txnFindRecordsImpl(
      SdbTransactionImpl txn,
      {SdbBoundaries<K>? boundaries}) {
    return txn.storeImpl(this).findRecords(boundaries: boundaries);
  }
}
