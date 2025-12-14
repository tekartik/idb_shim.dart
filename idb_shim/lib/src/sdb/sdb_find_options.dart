import 'package:idb_shim/sdb.dart';

/// Common find options
class SdbFindOptions {
  /// Filter
  final SdbFilter? filter;

  /// Limit
  final int? limit;

  /// Offset
  final int? offset;

  /// Descending order
  final bool? descending;

  /// Common find options
  SdbFindOptions({this.filter, this.limit, this.offset, this.descending});

  @override
  String toString() {
    var sb = StringBuffer();
    sb.write('SdbFindOptions(');
    var parts = <String>[];
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
  SdbFindOptions copyWith({
    SdbFilter? filter,
    int? limit,
    int? offset,
    bool? descending,
  }) {
    return SdbFindOptions(
      filter: filter ?? this.filter,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      descending: descending ?? this.descending,
    );
  }
}

/// Compatibility merge find options
/// Never null
SdbFindOptions compatMergeFindOptions(
  SdbFindOptions? options, {
  int? limit,
  int? offset,
  bool? descending,
  SdbFilter? filter,
}) {
  return options ??
      SdbFindOptions(
        limit: limit,
        offset: offset,
        descending: descending,
        filter: filter,
      );
}
