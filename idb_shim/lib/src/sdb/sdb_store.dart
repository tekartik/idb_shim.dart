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

  /// Add a single record.
  Future<K> add(SdbClient client, V value) => impl.addImpl(client, value);

  /// Put a single record (when using inline keys)
  Future<K> put(SdbClient client, V value) => impl.putImpl(client, value);

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecords(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
  }) => impl.findRecordsImpl(
    client,
    boundaries: boundaries,
    offset: offset,
    limit: limit,
  );

  /// Find records.
  Future<List<SdbRecordKey<K, V>>> findRecordKeys(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
  }) => impl.findRecordKeysImpl(
    client,
    boundaries: boundaries,
    offset: offset,
    limit: limit,
  );

  /// Count records.
  Future<int> count(SdbClient client, {SdbBoundaries<K>? boundaries}) =>
      impl.countImpl(client, boundaries: boundaries);

  /// Delete records.
  Future<void> delete(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
  }) => impl.deleteImpl(
    client,
    boundaries: boundaries,
    offset: offset,
    limit: limit,
  );

  /// Record reference.
  SdbRecordRef<K, V> record(K key) => SdbRecordRefImpl<K, V>(impl, key);

  /// Index reference on 1 field
  SdbIndex1Ref<K, V, I> index<I extends IndexBase>(String name) =>
      SdbIndex1RefImpl<K, V, I>(impl, name);

  /// Index reference on 2 fields
  SdbIndex2Ref<K, V, I1, I2> index2<I1 extends IndexBase, I2 extends IndexBase>(
    String name,
  ) => SdbIndex2RefImpl<K, V, I1, I2>(impl, name);

  /// Index reference on 3 fields
  SdbIndex3Ref<K, V, I1, I2, I3> index3<
    I1 extends IndexBase,
    I2 extends IndexBase,
    I3 extends IndexBase
  >(String name) => SdbIndex3RefImpl<K, V, I1, I2, I3>(impl, name);

  /// Index reference on 4 fields
  SdbIndex4Ref<K, V, I1, I2, I3, I4> index4<
    I1 extends IndexBase,
    I2 extends IndexBase,
    I3 extends IndexBase,
    I4 extends IndexBase
  >(String name) => SdbIndex4RefImpl<K, V, I1, I2, I3, I4>(impl, name);

  /// Lower boundary
  SdbBoundary<K> lowerBoundary(K value, {bool? include = true}) =>
      SdbLowerBoundary(value, include: include);

  /// Upper boundary
  SdbBoundary<K> upperBoundary(K value, {bool? include = false}) =>
      SdbUpperBoundary(value, include: include);
}

/// Store methods.
extension SdbStoreRefExtension<K extends KeyBase, V extends ValueBase>
    on SdbStoreRef<K, V> {}
