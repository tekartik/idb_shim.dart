import 'package:idb_shim/sdb.dart';

/// Common find options, boundaries key
class SdbFindOptions<K extends SdbKey> {
  /// Optional bounderies, when supported
  final SdbBoundaries<K>? boundaries;

  /// Optional filter, when supported
  /// Warning, will happen in memory once boundaries are applied
  final SdbFilter? filter;

  /// Limit
  final int? limit;

  /// Offset
  final int? offset;

  /// Descending order
  final bool? descending;

  /// Common find options
  SdbFindOptions({
    this.boundaries,
    this.filter,
    this.limit,
    this.offset,
    this.descending,
  });

  @override
  String toString() {
    var sb = StringBuffer();
    sb.write('SdbFindOptions(');
    var parts = <String>[];
    if (boundaries != null) {
      parts.add('boundaries: $boundaries');
    }
    if (limit != null) {
      parts.add('limit: $limit');
    }
    if (offset != null) {
      parts.add('offset: $offset');
    }
    if (descending != null) {
      parts.add('descending: $descending');
    }
    if (filter != null) {
      parts.add('filter: $filter');
    }
    sb.write(parts.join(', '));
    sb.write(')');
    return sb.toString();
  }

  /// Copy with
  SdbFindOptions<K> copyWith({
    SdbFilter? filter,
    int? limit,
    int? offset,
    bool? descending,
    SdbBoundaries<K>? boundaries,
  }) {
    return SdbFindOptions(
      filter: filter ?? this.filter,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      descending: descending ?? this.descending,
      boundaries: boundaries ?? this.boundaries,
    );
  }
}

/// Compatibility merge find options
/// Never null
SdbFindOptions<K> compatMergeFindOptions<K extends SdbKey>(
  SdbFindOptions<K>? options, {
  SdbBoundaries<K>? boundaries,
  int? limit,
  int? offset,
  bool? descending,
  SdbFilter? filter,
}) {
  return options ??
      SdbFindOptions<K>(
        boundaries: boundaries,
        limit: limit,
        offset: offset,
        descending: descending,
        filter: filter,
      );
}
