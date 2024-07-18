import 'sdb_boundary.dart';
import 'sdb_client.dart';
import 'sdb_index_impl.dart';
import 'sdb_index_record.dart';
import 'sdb_index_record_impl.dart';
import 'sdb_index_record_snapshot.dart';
import 'sdb_store.dart';
import 'sdb_types.dart';

/// Index reference.
abstract class SdbIndexRef<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> {
  /// Store reference.
  SdbStoreRef<K, V> get store;

  /// Index name.
  String get name;
}

/// Store methods.
extension SdbIndexRefExtension<K extends KeyBase, V extends ValueBase,
    I extends IndexBase> on SdbIndexRef<K, V, I> {
  /// Record reference.
  SdbIndexRecordRef<K, V, I> record(I indexKey) =>
      SdbIndexRecordRefImpl<K, V, I>(impl, indexKey);

  /// Find records.
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> findRecords(SdbClient client,
          {SdbBoundaries<I>? boundaries, int? offset, int? limit}) =>
      impl.findRecordsImpl(client,
          boundaries: boundaries, offset: offset, limit: limit);

  /// Find records.
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeys(SdbClient client,
          {SdbBoundaries<I>? boundaries, int? offset, int? limit}) =>
      impl.findRecordKeysImpl(client,
          boundaries: boundaries, offset: offset, limit: limit);
}
