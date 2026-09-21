import 'package:idb_shim/src/utils/cursor_utils.dart';

/// Internal: native join query support.
///
/// Implemented by an [ObjectStore] or an [Index] implementation able to
/// resolve a join in its own backend (typically an sql `LEFT JOIN`) instead of
/// reading the joined rows one by one. An implementation walking a cursor has
/// to issue one read per distinct join key, which the sdb layer does by
/// default.
///
/// The receiver is the iterated (source) side: an object store iterates its
/// records in primary key order, an index iterates them in index key order.
///
/// This is only used by the sdb layer, and only when no filter is involved
/// (a filter is applied in dart, so the limit cannot be pushed down). It is
/// deliberately not part of the public idb API: it carries no guarantee and
/// can change at any time.
///
/// The returned values are handed out as is, an implementation must return
/// values that are not shared with its internal state (i.e. decoded or
/// cloned).
abstract class IdbJoinQuerySupport {
  /// Rows of [range] in [direction], each carrying the row it joins with.
  ///
  /// The join key of a row is the value at [joinKeyPath] in its value, or,
  /// when [joinKeyPath] is null, the key the receiver iterates by: the primary
  /// key for an object store, the index key for an index.
  ///
  /// The joined row is the one of [joinStoreName] whose primary key is that
  /// join key, or, when [joinIndexName] is given, every row of that index of
  /// [joinStoreName] whose index key is that join key. An index key can match
  /// several rows, so a source row then yields as many rows as it matches
  /// (none of its own when it matches nothing, unless [inner] drops it), the
  /// way an sql join does.
  ///
  /// Returns `null` when this particular join cannot be resolved natively
  /// (an unsupported key path, a backend missing the needed sql support...).
  /// The caller must then fall back to reading the joined rows one by one, so
  /// an implementation returning `null` must do so before reading anything.
  ///
  /// [direction] is [idbDirectionNext] or [idbDirectionPrev], null meaning
  /// [idbDirectionNext]. [offset] and [limit] apply to the rows returned,
  /// i.e. after [inner] dropped the rows without a joined row.
  ///
  /// [withValue] and [withJoinedValue] tell which side the caller needs; a
  /// side that is not wanted is left `null` in the returned rows and does not
  /// have to be read at all.
  Future<List<IdbJoinRow>?> joinedRowList({
    required String joinStoreName,
    String? joinIndexName,
    String? joinKeyPath,
    KeyRange? range,
    String? direction,
    int? offset,
    int? limit,
    bool inner = false,
    bool withValue = true,
    bool withJoinedValue = true,
  });
}

/// A row read through [IdbJoinQuerySupport.joinedRowList].
class IdbJoinRow {
  /// Create a join row.
  IdbJoinRow({
    required this.primaryKey,
    this.value,
    this.joinKey,
    this.joinedPrimaryKey,
    this.joinedValue,
  });

  /// The primary key of the row in the iterated (source) store.
  final Object primaryKey;

  /// The value of the row in the iterated store, null when the caller asked
  /// not to read it.
  final Object? value;

  /// The key the joined row was looked up with, null when the source row has
  /// no value at the join key path.
  final Object? joinKey;

  /// The primary key of the joined row, null when there is none.
  ///
  /// Same as [joinKey] when the join is on the primary key of the joined
  /// store, but not when it goes through one of its indexes.
  final Object? joinedPrimaryKey;

  /// The value of the joined row, null when there is none, or when the caller
  /// asked not to read it.
  final Object? joinedValue;

  @override
  String toString() => 'IdbJoinRow($primaryKey -> $joinKey: $joinedPrimaryKey)';
}

/// The [IdbJoinQuerySupport] of [object], null when the implementation cannot
/// resolve a join natively (the caller must then read the joined rows one by
/// one).
IdbJoinQuerySupport? idbJoinQuerySupportOrNull(Object? object) =>
    object is IdbJoinQuerySupport ? object : null;
