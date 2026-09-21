/// Rows read per query when a join is resolved through an implementation able
/// to join natively.
///
/// Same trade-off as the paged iterate chunk size: small enough to stop early
/// cheaply, big enough to keep the number of queries low.
const sdbJoinIterateChunkSize = 200;

/// The join specific options, shared by every join method and by the runner
/// resolving it.
///
/// Deliberately not a `SdbFindOptions`: the two describe different things and
/// every join method takes both. `options` says what is read on the iterated
/// side (its boundaries, filter, order, offset and limit), this says how the
/// two sides are joined.
class SdbJoinFindOptions {
  /// Join options.
  const SdbJoinFindOptions({bool? distinct, bool? inner, int? chunkSize})
    : distinct = distinct ?? false,
      inner = inner ?? false,
      chunkSize = chunkSize ?? sdbJoinIterateChunkSize;

  /// Only expand the first source record of each join key, the records
  /// without a join key counting as one group.
  ///
  /// False by default. It is what you want when you iterate a store only to
  /// reach the records it references.
  final bool distinct;

  /// Drop the rows with no joined record, an sql `INNER JOIN`.
  ///
  /// False by default, so a record whose join key is null, or whose join key
  /// matches nothing, is still handed out.
  final bool inner;

  /// Rows read per query when the implementation joins natively.
  ///
  /// Defaults to [sdbJoinIterateChunkSize].
  final int chunkSize;

  @override
  String toString() {
    var parts = <String>[];
    if (distinct) {
      parts.add('distinct: $distinct');
    }
    if (inner) {
      parts.add('inner: $inner');
    }
    if (chunkSize != sdbJoinIterateChunkSize) {
      parts.add('chunkSize: $chunkSize');
    }
    return 'SdbJoinFindOptions(${parts.join(', ')})';
  }

  /// Copy with.
  SdbJoinFindOptions copyWith({bool? distinct, bool? inner, int? chunkSize}) {
    return SdbJoinFindOptions(
      distinct: distinct ?? this.distinct,
      inner: inner ?? this.inner,
      chunkSize: chunkSize ?? this.chunkSize,
    );
  }
}

/// The default join options, everything left to its default.
const sdbJoinFindOptionsDefault = SdbJoinFindOptions();

/// [options], or [sdbJoinFindOptionsDefault] when null.
SdbJoinFindOptions sdbJoinFindOptionsOrDefault(SdbJoinFindOptions? options) =>
    options ?? sdbJoinFindOptionsDefault;
