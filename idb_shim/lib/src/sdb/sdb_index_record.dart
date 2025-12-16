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

  SdbBoundaries<I> get _boundariesKey => SdbBoundaries.key(indexKey);

  /// Find all records with this index key.
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeys(
    SdbClient client,
    SdbFindOptions<I> options,
  ) => index.findRecordKeys(
    client,
    boundaries: _boundariesKey,
    options: options,
  );

  /// Find all records with this index key.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> findRecords(
    SdbClient client, {
    SdbFindOptions<I>? options,
  }) {
    return index.findRecords(
      client,
      boundaries: _boundariesKey,
      options: options,
    );
  }

  ///
  Future<int> count(SdbClient client, {SdbFindOptions<I>? options}) {
    return index.count(client, boundaries: _boundariesKey, options: options);
  }
}
