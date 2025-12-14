import 'sdb.dart';
import 'sdb_index_impl.dart';
import 'sdb_store_impl.dart';

/// A simple db store definition.
abstract class SdbStoreRef<K extends SdbKey, V extends SdbValue> {
  /// Store name.
  String get name;

  /// Store definition.
  factory SdbStoreRef(String name) => SdbStoreRefImpl(name);
}

/// Store methods.
extension SdbStoreRefExtension<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// Index reference on 1 field
  SdbIndex1Ref<K, V, I> index<I extends SdbIndexKey>(String name) =>
      SdbIndex1RefImpl<K, V, I>(impl, name);

  /// Index reference on 2 fields
  SdbIndex2Ref<K, V, I1, I2>
  index2<I1 extends SdbIndexKey, I2 extends SdbIndexKey>(String name) =>
      SdbIndex2RefImpl<K, V, I1, I2>(impl, name);

  /// Index reference on 3 fields
  SdbIndex3Ref<K, V, I1, I2, I3> index3<
    I1 extends SdbIndexKey,
    I2 extends SdbIndexKey,
    I3 extends SdbIndexKey
  >(String name) => SdbIndex3RefImpl<K, V, I1, I2, I3>(impl, name);

  /// Index reference on 4 fields
  SdbIndex4Ref<K, V, I1, I2, I3, I4> index4<
    I1 extends SdbIndexKey,
    I2 extends SdbIndexKey,
    I3 extends SdbIndexKey,
    I4 extends SdbIndexKey
  >(String name) => SdbIndex4RefImpl<K, V, I1, I2, I3, I4>(impl, name);

  /// Lower boundary
  SdbBoundary<K> lowerBoundary(K value, {bool? include = true}) =>
      SdbLowerBoundary(value, include: include);

  /// Upper boundary
  SdbBoundary<K> upperBoundary(K value, {bool? include = false}) =>
      SdbUpperBoundary(value, include: include);
}
