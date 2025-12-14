import 'package:idb_shim/idb.dart' as idb;

import 'sdb_boundary.dart';
import 'sdb_key_utils.dart';

/// Lower or upper boundary implementation.
class DbBoundaryImpl<T extends Object>
    implements SdbLowerBoundary<T>, SdbUpperBoundary<T> {
  @override
  final T value;
  @override
  final bool include;

  /// Lower or upper boundary implementation.
  DbBoundaryImpl(this.value, this.include);

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is SdbBoundary) {
      return value == other.value && include == other.include;
    }
    return false;
  }

  @override
  String toString() => '$value ${include ? '(included)' : '(excluded)'}';
}

mixin _SdbBoundariesMixin<T extends Object> implements SdbBoundaries<T> {
  @override
  String toConditionString() {
    var sb = StringBuffer();
    if (lower != null) {
      var value = lower!.value;
      if (value == upper?.value && lower!.include && upper!.include) {
        // equal
        sb.write('? == $value');
        return sb.toString();
      }
      sb.write('$value ${lower!.include ? '<=' : '<'} ');
    }
    sb.write('?');

    if (upper != null) {
      sb.write(' ${upper!.include ? '<=' : '<'} ${upper!.value}');
    }
    return sb.toString();
  }

  @override
  String toString() => toConditionString();

  @override
  int get hashCode {
    return lower.hashCode ^ upper.hashCode;
  }

  @override
  bool operator ==(Object other) {
    if (other is SdbBoundaries) {
      return lower == other.lower && upper == other.upper;
    }
    return false;
  }
}

/// Single key boundaries implementation.
class SdbSingleKeyBoundaries<T extends Object>
    with _SdbBoundariesMixin<T>
    implements SdbBoundaries<T> {
  /// The single key.
  final T key;

  /// Single key boundaries implementation.
  SdbSingleKeyBoundaries(this.key);

  @override
  late final lower = SdbLowerBoundary(key, include: true);

  @override
  late final upper = SdbUpperBoundary(key, include: true);
}

/// Lower and upper boundaries implementation.
class SdbBoundariesImpl<T extends Object>
    with _SdbBoundariesMixin<T>
    implements SdbBoundaries<T> {
  @override
  final SdbBoundary<T>? lower;
  @override
  final SdbBoundary<T>? upper;

  /// Lower and upper boundaries implementation.
  SdbBoundariesImpl(this.lower, this.upper);
}

/// Convert boundaries to idb.KeyRange.
idb.KeyRange? idbKeyRangeFromBoundaries(SdbBoundaries? boundaries) {
  var lower = boundaries?.lower;
  var upper = boundaries?.upper;
  if (boundaries == null) {
    return null;
  } else if (lower == null) {
    if (upper == null) {
      return null;
    } else {
      return idb.KeyRange.upperBound(
        indexKeyToIdbKey(upper.value),
        !upper.include,
      );
    }
  } else if (upper == null) {
    return idb.KeyRange.lowerBound(
      indexKeyToIdbKey(lower.value),
      !lower.include,
    );
  } else {
    return idb.KeyRange.bound(
      indexKeyToIdbKey(lower.value),
      indexKeyToIdbKey(upper.value),
      !lower.include,
      !upper.include,
    );
  }
}
