import 'sdb_boundary.dart';
import 'sdb_client.dart';
import 'sdb_index.dart';
import 'sdb_index_impl.dart';
import 'sdb_record.dart';
import 'sdb_record_impl.dart';
import 'sdb_record_snapshot.dart';
import 'sdb_store_impl.dart';
import 'sdb_types.dart';

/// A simple db store definition.
abstract class SdbStoreRef<K extends KeyBase, V extends ValueBase> {
  /// Store name.
  String get name;

  /// Store definition.
  factory SdbStoreRef(String name) => SdbStoreRefImpl(name);
}

/// Store methods.
extension SdbStoreRefExtension<K extends KeyBase, V extends ValueBase>
    on SdbStoreRef<K, V> {
  /// Get a single record.
  Future<K> add(SdbClient client, V value) => impl.addImpl(client, value);

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecords(SdbClient client,
          {SdbBoundaries<K>? boundaries}) =>
      impl.findRecordsImpl(client, boundaries: boundaries);

  /// Record reference.
  SdbRecordRef<K, V> record(K key) => SdbRecordRefImpl<K, V>(impl, key);

  /// Index reference
  SdbIndexRef<K, V, I> index<I extends IndexBase>(String name) =>
      SdbIndexRefImpl<K, V, I>(impl, name);

  /// Index reference
  SdbIndexRef<K, V, (I1, I2)>
      index2<I1 extends IndexBase, I2 extends IndexBase>(String name) =>
          SdbIndexRefImpl<K, V, (I1, I2)>(impl, name);
}
