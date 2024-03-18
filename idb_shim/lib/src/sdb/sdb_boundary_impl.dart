import 'package:idb_shim/idb.dart' as idb;

import 'sdb_boundary.dart';

/// Lower or upper boundary implementation.
class DbBoundaryImpl<T extends Object>
    implements SdbLowerBoundary<T>, SdbUpperBoundary<T> {
  @override
  final T value;
  @override
  final bool include;

  /// Lower or upper boundary implementation.
  DbBoundaryImpl(this.value, this.include);
}

/// Lower and upper boundaries implementation.
class DbBoundariesImpl<T extends Object> implements SdbBoundaries<T> {
  @override
  final SdbBoundary<T>? lower;
  @override
  final SdbBoundary<T>? upper;

  /// Lower and upper boundaries implementation.
  DbBoundariesImpl(this.lower, this.upper);

  @override
  String toString() {
    var sb = StringBuffer();
    if (lower != null) {
      sb.write('${lower!.value} ${lower!.include ? '<=' : '<'} ');
    }
    sb.write('?');

    if (upper != null) {
      sb.write(' ${upper!.include ? '<=' : '<'} ${upper!.value}');
    }
    return sb.toString();
  }
}

/// Convert boundaries to idb.KeyRange.
idb.KeyRange? idbKeyRangeFromBoundaries(SdbBoundaries? boundaries) {
  if (boundaries == null) {
    return null;
  } else if (boundaries.lower == null) {
    if (boundaries.upper == null) {
      return null;
    } else {
      return idb.KeyRange.lowerBound(
          boundaries.upper!.value, !boundaries.upper!.include);
    }
  } else if (boundaries.upper == null) {
    return idb.KeyRange.upperBound(
        boundaries.lower!.value, !boundaries.lower!.include);
  } else {
    return idb.KeyRange.bound(boundaries.lower!.value, boundaries.upper!.value,
        !boundaries.lower!.include, !boundaries.upper!.include);
  }
}
