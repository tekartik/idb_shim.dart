import 'package:idb_shim/sdb.dart';

/// What a join key is matched against.
///
/// Either a store, on its primary key (at most one record per key), or an
/// index, on its index key (any number of records per key, a source record
/// then giving one row per match).
///
/// It is exactly one of the two by construction: a join method takes one
/// required [SdbJoinTarget], so passing neither or both is a compile error
/// rather than something failing at run time.
///
/// Build one with [SdbJoinTarget.store] / [SdbJoinTarget.index], or with the
/// `asJoinTarget` getter on a store or an index ref.
abstract class SdbJoinTarget<JK extends SdbKey, JV extends SdbValue> {
  /// Match the join key against the primary key of [store].
  factory SdbJoinTarget.store(SdbStoreRef<JK, JV> store) =
      _SdbJoinStoreTarget<JK, JV>;

  /// Match the join key against [index].
  factory SdbJoinTarget.index(SdbIndexRef<JK, JV, SdbIndexKey> index) =
      _SdbJoinIndexTarget<JK, JV>;

  /// The store holding the joined records, whichever way they are matched.
  SdbStoreRef<JK, JV> get store;

  /// The index the join key is matched against, null when it is matched
  /// against the primary key of [store].
  SdbIndexRef<JK, JV, SdbIndexKey>? get index;
}

/// A join on the primary key of a store.
class _SdbJoinStoreTarget<JK extends SdbKey, JV extends SdbValue>
    implements SdbJoinTarget<JK, JV> {
  _SdbJoinStoreTarget(this.store);

  @override
  final SdbStoreRef<JK, JV> store;

  @override
  SdbIndexRef<JK, JV, SdbIndexKey>? get index => null;

  @override
  String toString() => 'SdbJoinTarget.store(${store.name})';
}

/// A join on an index.
class _SdbJoinIndexTarget<JK extends SdbKey, JV extends SdbValue>
    implements SdbJoinTarget<JK, JV> {
  _SdbJoinIndexTarget(this.index);

  @override
  final SdbIndexRef<JK, JV, SdbIndexKey> index;

  @override
  SdbStoreRef<JK, JV> get store => index.store;

  @override
  String toString() => 'SdbJoinTarget.index(${store.name}.${index.name})';
}

/// Using a store as a join target.
extension SdbStoreRefJoinTargetExtension<JK extends SdbKey, JV extends SdbValue>
    on SdbStoreRef<JK, JV> {
  /// This store as a join target, matched on its primary key.
  SdbJoinTarget<JK, JV> get asJoinTarget => SdbJoinTarget.store(this);
}

/// Using an index as a join target.
extension SdbIndexRefJoinTargetExtension<
  JK extends SdbKey,
  JV extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndexRef<JK, JV, I> {
  /// This index as a join target, matched on its index key.
  SdbJoinTarget<JK, JV> get asJoinTarget => SdbJoinTarget.index(this);
}
