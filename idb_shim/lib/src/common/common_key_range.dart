import 'package:idb_shim/idb.dart';

/// See [KeyRange] for information
class IdbKeyRange implements KeyRange {
  /// Should not be used.
  @deprecated
  IdbKeyRange();

  /// Creates a new key range containing a single value.
  IdbKeyRange.only(/*Key*/ value) : this.bound(value, value);

  /// Creates a new key range with only a lower bound.
  IdbKeyRange.lowerBound(this._lowerBound, [bool open = false]) {
    _lowerBoundOpen = open;
  }

  /// Creates a new upper-bound key range.
  IdbKeyRange.upperBound(this._upperBound, [bool open = false]) {
    _upperBoundOpen = open;
  }

  /// Creates a new key range with upper and lower bounds.
  IdbKeyRange.bound(this._lowerBound, this._upperBound,
      [bool lowerOpen = false, bool upperOpen = false]) {
    _lowerBoundOpen = lowerOpen;
    _upperBoundOpen = upperOpen;
  }

  dynamic _lowerBound;
  bool _lowerBoundOpen = true;
  dynamic _upperBound;
  bool _upperBoundOpen = true;

  /// Lower bound of the key range.
  @override
  Object? get lower => _lowerBound;

  /// Returns false if the lower-bound value is included in the key range.
  @override
  bool get lowerOpen => _lowerBoundOpen;

  /// Upper bound of the key range.
  @override
  Object? get upper => _upperBound;

  /// Returns false if the upper-bound value is included in the key range.
  @override
  bool get upperOpen => _upperBoundOpen;

  num _compareValue(value1, value2) {
    if (value1 is num) {
      return value1 - (value2 as num);
    } else if (value1 is String) {
      return value1.compareTo(value2 as String);
    } else if (value1 is List) {
      final list = value1;
      for (var i = 0; i < list.length; i++) {
        var diff = _compareValue(list[i], (value2 as List)[i]);
        if (diff != 0) {
          return diff;
        }
      }
      return 0;
    } else {
      throw UnsupportedError(
          "key '$value1' of type ${value1.runtimeType} not supported");
    }
  }

  ///
  /// Added method for memory implementation
  ///
  bool _checkLowerBound(key) {
    if (_lowerBound != null) {
      final exclude = _lowerBoundOpen;
      final cmp = _compareValue(key, _lowerBound);
      if (cmp == 0 && exclude) {
        return false;
      } else {
        return cmp >= 0;
      }
    }
    return true;
  }

  bool _checkUpperBound(key) {
    if (_upperBound != null) {
      final exclude = _upperBoundOpen;
      final cmp = _compareValue(key, _upperBound);
      if (cmp == 0 && exclude) {
        return false;
      } else {
        return cmp <= 0;
      }
    }
    return true;
  }

  /// Return true if a key range contains a given key
  @override
  bool contains(key) {
    if (!_checkLowerBound(key)) {
      return false;
    } else {
      return _checkUpperBound(key);
    }
  }

  @override
  String toString() {
    final sb = StringBuffer('kr');
    if (lower == null) {
      sb.write('...');
    } else {
      if (lowerOpen) {
        sb.write(']');
      } else {
        sb.write('[');
      }
      sb.write(lower);
    }
    sb.write('-');
    if (upper == null) {
      sb.write('...');
    } else {
      sb.write(upper);
      if (upperOpen) {
        sb.write('[');
      } else {
        sb.write(']');
      }
    }
    return sb.toString();
  }
}
