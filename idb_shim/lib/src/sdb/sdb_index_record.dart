import 'sdb.dart';
import 'sdb_index_record_impl.dart';

/// Index record reference at a given index key.
/// An index key may refer to multiple records.
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

  /// Get a single record value.
  Future<V?> getValue(SdbClient client) async =>
      (await impl.getImpl(client))?.value;

  /// Get a single record key.
  Future<K?> getKey(SdbClient client) => impl.getKeyImpl(client);

  SdbBoundaries<I> get _boundariesKey => SdbBoundaries.key(indexKey);

  /// Find all records with this index key.
  Future<List<K>> findKeys(
    SdbClient client, {
    SdbFindOptions<I>? options,
  }) async => (await index.findRecordKeys(
    client,
    options: _mergeOptions(options),
  )).map((e) => e.key).toList();

  /// Find all records with this index key.
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeys(
    SdbClient client, {
    SdbFindOptions<I>? options,
  }) async => (await index.findRecordKeys(
    client,
    options: _mergeOptions(options),
  )).toList();

  /// Find all records with this index key.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> findRecords(
    SdbClient client, {
    SdbFindOptions<I>? options,
  }) {
    return index.findRecords(client, options: _mergeOptions(options));
  }

  SdbFindOptions<I> _mergeOptions(SdbFindOptions<I>? options) {
    assert(options?.boundaries == null);
    return sdbFindOptionsMerge(options).copyWith(boundaries: _boundariesKey);
  }

  /// Count all records with this index key.
  Future<int> count(SdbClient client, {SdbFindOptions<I>? options}) {
    return index.count(client, options: _mergeOptions(options));
  }

  /// Delete all records with this index key.
  Future<void> delete(SdbClient client, {SdbFindOptions<I>? options}) async {
    await index.delete(client, options: _mergeOptions(options));
  }
}
