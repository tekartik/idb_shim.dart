import 'package:idb_shim/sdb.dart';

/// What a join iterates, and where it reads the join key of each record.
///
/// Either a store, in primary key order, or an index, in index key order. The
/// mirror of [SdbJoinTarget]: a join is one source and one target, and every
/// join method takes both.
///
/// The third type parameter is the key the iteration is ordered and bounded
/// by: the primary key of a store, the index key of an index. It is what
/// `SdbFindOptions` applies to, so the boundaries of a join always have the
/// type of the key that is actually walked.
///
/// Build one with the `asJoinSource` getter on a store or an index, or with
/// `asJoinSourceAt` on a store to read the join key from a field:
///
/// ```dart
/// bookStore.asJoinSourceAt('authorId') // store, join key in a field
/// postStore.asJoinSource               // store, join key is its primary key
/// bookAuthorIndex.asJoinSource         // index, join key is its index key
/// ```
abstract class SdbJoinSource<
  K extends SdbKey,
  V extends SdbValue,
  SK extends SdbKey
> {
  /// The store holding the iterated records, whichever way they are walked.
  SdbStoreRef<K, V> get store;

  /// The index the records are walked through, null when [store] is walked in
  /// primary key order.
  SdbIndexRef<K, V, SdbIndexKey>? get index;

  /// Field path holding the join key, null when the key the iteration is
  /// ordered by is the join key.
  ///
  /// Always null for an index source: the index key is the join key.
  String? get joinKeyPath;

  /// Internal: the boundaries to hand to the store scan, null when walking an
  /// index (the boundaries then apply to the index key, and only reach the
  /// scan as a resolved range).
  SdbBoundaries<K>? sourceBoundariesOf(SdbFindOptions<SK>? options);

  /// Internal: the number of records [options] selects, without any join.
  Future<int> countRecords(SdbClient client, SdbFindOptions<SK>? options);
}

/// A join iterating a store in primary key order.
class _SdbJoinStoreSource<K extends SdbKey, V extends SdbValue>
    implements SdbJoinSource<K, V, K> {
  _SdbJoinStoreSource(this.store, this.joinKeyPath);

  @override
  final SdbStoreRef<K, V> store;

  @override
  final String? joinKeyPath;

  @override
  SdbIndexRef<K, V, SdbIndexKey>? get index => null;

  @override
  SdbBoundaries<K>? sourceBoundariesOf(SdbFindOptions<K>? options) =>
      options?.boundaries;

  @override
  Future<int> countRecords(SdbClient client, SdbFindOptions<K>? options) =>
      store.count(client, options: options);

  @override
  String toString() =>
      'SdbJoinSource.store(${store.name}${joinKeyPath == null ? '' : '.$joinKeyPath'})';
}

/// A join iterating an index in index key order.
class _SdbJoinIndexSource<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbJoinSource<K, V, I> {
  _SdbJoinIndexSource(this.index);

  @override
  final SdbIndexRef<K, V, I> index;

  @override
  SdbStoreRef<K, V> get store => index.store;

  /// The index key is the join key.
  @override
  String? get joinKeyPath => null;

  @override
  SdbBoundaries<K>? sourceBoundariesOf(SdbFindOptions<I>? options) => null;

  @override
  Future<int> countRecords(SdbClient client, SdbFindOptions<I>? options) =>
      index.count(client, options: options);

  @override
  String toString() => 'SdbJoinSource.index(${store.name}.${index.name})';
}

/// Using a store as a join source.
extension SdbStoreRefJoinSourceExtension<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// This store as a join source, walked in primary key order, its primary
  /// key being the join key.
  ///
  /// That is what a one to many join from the parent side needs; use
  /// [asJoinSourceAt] to read the join key from a field instead.
  SdbJoinSource<K, V, K> get asJoinSource =>
      _SdbJoinStoreSource<K, V>(this, null);

  /// This store as a join source, walked in primary key order, the join key
  /// being the value at [joinKeyPath].
  ///
  /// [joinKeyPath] is a field path, dot separated for a nested field.
  SdbJoinSource<K, V, K> asJoinSourceAt(String joinKeyPath) =>
      _SdbJoinStoreSource<K, V>(this, joinKeyPath);
}

/// Using an index as a join source.
extension SdbIndexRefJoinSourceExtension<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndexRef<K, V, I> {
  /// This index as a join source, walked in index key order, its index key
  /// being the join key.
  ///
  /// The shape to prefer: there is no key path to read, so an implementation
  /// able to join natively takes the join key straight from the index. A
  /// record with no index key is not in the index and never shows up.
  SdbJoinSource<K, V, I> get asJoinSource => _SdbJoinIndexSource<K, V, I>(this);
}
