import 'sdb_boundary.dart';
import 'sdb_client.dart';
import 'sdb_filter.dart';
import 'sdb_index_impl.dart';
import 'sdb_index_record.dart';
import 'sdb_index_record_impl.dart';
import 'sdb_index_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// Index reference.
abstract interface class SdbIndexRef<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Index name.
  String get name;
}

/// Index on 1 field
abstract interface class SdbIndex1Ref<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    extends SdbIndexRef<K, V, I> {}

/// Index on 2 fields
abstract interface class SdbIndex2Ref<
  K extends SdbKey,
  V extends SdbValue,
  I1 extends SdbIndexKey,
  I2 extends SdbIndexKey
>
    extends SdbIndexRef<K, V, (I1, I2)> {}

/// Index on 3 fields
abstract interface class SdbIndex3Ref<
  K extends SdbKey,
  V extends SdbValue,
  I1 extends SdbIndexKey,
  I2 extends SdbIndexKey,
  I3 extends SdbIndexKey
>
    extends SdbIndexRef<K, V, (I1, I2, I3)> {}

/// Index on 4 fields
abstract interface class SdbIndex4Ref<
  K extends SdbKey,
  V extends SdbValue,
  I1 extends SdbIndexKey,
  I2 extends SdbIndexKey,
  I3 extends SdbIndexKey,
  I4 extends SdbIndexKey
>
    extends SdbIndexRef<K, V, (I1, I2, I3, I4)> {}

/// Index methods.
extension SdbIndexRefExtension<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndexRef<K, V, I> {
  /// Record reference.
  SdbIndexRecordRef<K, V, I> record(I indexKey) =>
      SdbIndexRecordRefImpl<K, V, I>(impl, indexKey);

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> findRecords(
    SdbClient client, {
    SdbBoundaries<I>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional descending order
    bool? descending,
  }) => impl.findRecordsImpl(
    client,
    boundaries: boundaries,
    filter: filter,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// Find records.
  Future<SdbIndexRecordSnapshot<K, V, I>?> findRecord(
    SdbClient client, {
    SdbBoundaries<I>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,

    /// Optional descending order
    bool? descending,
  }) async {
    var records = await findRecords(
      client,
      boundaries: boundaries,
      filter: filter,
      offset: offset,
      limit: 1,
      descending: descending,
    );
    return records.firstOrNull;
  }

  /// Find record keys.
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeys(
    SdbClient client, {
    SdbBoundaries<I>? boundaries,
    int? offset,
    int? limit,

    /// Optional descending order
    bool? descending,
  }) => impl.findRecordKeysImpl(
    client,
    boundaries: boundaries,
    offset: offset,
    limit: limit,
    descending: descending,
  );

  /// Find first record key.
  Future<SdbIndexRecordKey<K, V, I>?> findRecordKey(
    SdbClient client, {
    SdbBoundaries<I>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,

    /// Optional descending order
    bool? descending,
  }) async {
    var records = await findRecordKeys(
      client,
      boundaries: boundaries,
      offset: offset,
      limit: 1,
      descending: descending,
    );
    return records.firstOrNull;
  }

  /// Count records.
  Future<int> count(SdbClient client, {SdbBoundaries<I>? boundaries}) =>
      impl.countImpl(client, boundaries: boundaries);

  /// Delete records.
  Future<void> delete(
    SdbClient client, {
    SdbBoundaries<I>? boundaries,
    int? offset,
    int? limit,

    /// Optional descending order
    bool? descending,
  }) => impl.deleteImpl(
    client,
    boundaries: boundaries,
    offset: offset,
    limit: limit,
    descending: descending,
  );
}

/// Extension on index on 1 field.
extension SdbIndex1RefExtension<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndex1Ref<K, V, I> {
  /// Lower boundary
  SdbBoundary<I> lowerBoundary(I value, {bool? include = true}) =>
      SdbLowerBoundary(value, include: include);

  /// Upper boundary
  SdbBoundary<I> upperBoundary(I value, {bool? include = false}) =>
      SdbUpperBoundary(value, include: include);
}

/// Extension on index on 2 fields.
extension SdbIndex2RefExtension<
  K extends SdbKey,
  V extends SdbValue,
  I1 extends SdbIndexKey,
  I2 extends SdbIndexKey
>
    on SdbIndex2Ref<K, V, I1, I2> {
  /// Lower boundary
  SdbBoundary<(I1, I2)> lowerBoundary(
    I1 value1,
    I2 value2, {
    bool? include = true,
  }) => SdbLowerBoundary((value1, value2), include: include);

  /// Upper boundary
  SdbBoundary<(I1, I2)> upperBoundary(
    I1 value1,
    I2 value2, {
    bool? include = false,
  }) => SdbUpperBoundary((value1, value2), include: include);
}

/// Extension on index on 3 fields.
extension SdbIndex3RefExtension<
  K extends SdbKey,
  V extends SdbValue,
  I1 extends SdbIndexKey,
  I2 extends SdbIndexKey,
  I3 extends SdbIndexKey
>
    on SdbIndex3Ref<K, V, I1, I2, I3> {
  /// Lower boundary
  SdbBoundary<(I1, I2, I3)> lowerBoundary(
    I1 value1,
    I2 value2,
    I3 value3, {
    bool? include = true,
  }) => SdbLowerBoundary((value1, value2, value3), include: include);

  /// Upper boundary
  SdbBoundary<(I1, I2, I3)> upperBoundary(
    I1 value1,
    I2 value2,
    I3 value3, {
    bool? include = false,
  }) => SdbUpperBoundary((value1, value2, value3), include: include);
}

/// Extension on index on 4 fields.
extension SdbIndex4RefExtension<
  K extends SdbKey,
  V extends SdbValue,
  I1 extends SdbIndexKey,
  I2 extends SdbIndexKey,
  I3 extends SdbIndexKey,
  I4 extends SdbIndexKey
>
    on SdbIndex4Ref<K, V, I1, I2, I3, I4> {
  /// Lower boundary
  SdbBoundary<(I1, I2, I3, I4)> lowerBoundary(
    I1 value1,
    I2 value2,
    I3 value3,
    I4 value4, {
    bool? include = true,
  }) => SdbLowerBoundary((value1, value2, value3, value4), include: include);

  /// Upper boundary
  SdbBoundary<(I1, I2, I3, I4)> upperBoundary(
    I1 value1,
    I2 value2,
    I3 value3,
    I4 value4, {
    bool? include = false,
  }) => SdbUpperBoundary((value1, value2, value3, value4), include: include);
}
