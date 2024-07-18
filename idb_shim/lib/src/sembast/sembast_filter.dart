// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/sembast/sembast_import.dart' as sembast;

/// keyPath must have been escaped before
sembast.Filter keyCursorFilter(
    dynamic keyPath, Object? key, KeyRange? range, bool multiEntry) {
  if (range != null) {
    return keyRangeFilter(keyPath, range, multiEntry);
  } else
  // if (key != null)
  {
    return keyFilter(keyPath, key, multiEntry);
  }
  // no filtering
  // return null;
}

// return <0 if value1 < value2 or >0 if greater
// returns 0 if cannot be compared or equals
int compareValue(dynamic value1, dynamic value2) {
  try {
    if (value1 is Comparable && value2 is Comparable) {
      return Comparable.compare(value1, value2);
    } else if (value1 is List && value2 is List) {
      final list1 = value1;
      final list2 = value2;

      for (var i = 0; i < min(value1.length, value2.length); i++) {
        final cmp = compareValue(list1[i], list2[i]);
        if (cmp == 0) {
          continue;
        }
        return cmp;
      }
      // Same ? return the length diff if any
      return compareValue(list1.length, list2.length);
    }
  } catch (_) {}
  return 0;
}

// Matches if <0
int lowerCompareSingleValue(dynamic lower, dynamic value) {
  if (value == null) {
    // failure for matches
    return 1;
  }
  return compareValue(lower, value);
}

// Matches if <0
int? lowerCompareValue(dynamic lower, dynamic value, bool multiEntry) {
  int? bestCmp;
  if (multiEntry && value is List) {
    for (var item in value) {
      final cmp = lowerCompareSingleValue(lower, item);
      if (cmp < 0) {
        return cmp;
      } else if (cmp == 0) {
        bestCmp = 0;
      }
    }
  }
  final singleCmp = lowerCompareSingleValue(lower, value);

  if (bestCmp != null) {
    return min(singleCmp, bestCmp);
  }
  return singleCmp;
}

// True if simple value matches lower bound
bool lowerMatchesSingleValue(dynamic lower, bool lowerOpen, dynamic value) {
  if (value != null) {
    final cmp = lowerCompareSingleValue(lower, value);
    if (cmp < 0) {
      return true;
    } else if (!lowerOpen) {
      return cmp == 0;
    }
  }
  return false;
}

// Matches if >0
int upperCompareSingleValue(dynamic upper, dynamic value) {
  if (value == null) {
    // failure for matches
    return -1;
  }
  return compareValue(upper, value);
}

// Matches if >0
int? upperCompareValue(dynamic lower, dynamic value, bool multiEntry) {
  int? bestCmp;
  if (multiEntry && value is List) {
    for (var item in value) {
      final cmp = upperCompareSingleValue(lower, item);
      if (cmp != 0) {
        return cmp;
      } else if (cmp == 0) {
        bestCmp = 0;
      }
    }
  }
  final singleCmp = upperCompareSingleValue(lower, value);

  if (bestCmp != null) {
    return max(singleCmp, bestCmp);
  }
  return singleCmp;
}

// True if simple value matches lower bound
bool upperMatchesSingleValue(dynamic upper, bool upperOpen, dynamic value) {
  if (value != null) {
    final cmp = upperCompareSingleValue(upper, value);
    if (cmp > 0) {
      return true;
    } else if (!upperOpen) {
      return cmp == 0;
    }
  }
  return false;
}

bool lowerMatchesValue(
    dynamic lower, bool lowerOpen, dynamic value, bool multiEntry) {
  if (multiEntry && value is List) {
    for (var item in value) {
      if (lowerMatchesSingleValue(lower, lowerOpen, item)) {
        return true;
      }
    }
    return false;
  }
  return lowerMatchesSingleValue(lower, lowerOpen, value);
}

bool upperMatchesValue(
    dynamic upper, bool upperOpen, dynamic value, bool multiEntry) {
  if (multiEntry && value is List) {
    for (var item in value) {
      if (upperMatchesSingleValue(upper, upperOpen, item)) {
        return true;
      }
    }
  }
  return upperMatchesSingleValue(upper, upperOpen, value);
}

sembast.Filter keyRangeFilter(
    dynamic keyPath, KeyRange range, bool multiEntry) {
  if (keyPath is String) {
    return sembast.Filter.custom((snapshot) {
      var value = snapshot[keyPath];
      if (range.lower != null) {
        if (!lowerMatchesValue(
            range.lower, range.lowerOpen, value, multiEntry)) {
          return false;
        }
      }
      if (range.upper != null) {
        if (!upperMatchesValue(
            range.upper, range.upperOpen, value, multiEntry)) {
          return false;
        }
      }
      return true;
    });
  } else if (keyPath is List) {
    var keyPathList = keyPath;
    var lowerList = range.lower as List?;
    var upperList = range.upper as List?;
    if (lowerList != null) {
      assert(lowerList.length == keyPathList.length,
          'keyPath and lower bound length must match');
    }
    if (upperList != null) {
      assert(upperList.length == keyPathList.length,
          'keyPath and upper bound length must match');
    }
    return sembast.Filter.custom((snapshot) {
      final values = List.generate(
          keyPathList.length, (i) => snapshot[keyPathList[i] as String]);

      // no null accepted
      for (var value in values) {
        if (value == null) {
          return false;
        }
      }

      final lowerOpen = range.lowerOpen;

      if (lowerList != null) {
        int? cmp;
        for (var i = 0; i < keyPathList.length; i++) {
          var value = values[i];
          var lower = lowerList[i];
          if (lower == null) {
            // matches!
            continue;
          } else {
            cmp = lowerCompareValue(lower, value, multiEntry);
            if (cmp! > 0) {
              return false;
            } else if (cmp < 0) {
              break;
            }
          }
        }
        // all matches
        if (cmp == 0 && lowerOpen) {
          return false;
        }
      }

      final upperOpen = range.upperOpen;

      if (upperList != null) {
        int? cmp;
        for (var i = 0; i < keyPathList.length; i++) {
          var value = values[i];
          var upper = upperList[i];
          if (upper == null) {
            // matches!
            continue;
          } else {
            cmp = upperCompareValue(upper, value, multiEntry);
            if (cmp! < 0) {
              return false;
            } else if (cmp > 0) {
              break;
            }
          }
        }
        // all matches
        if (cmp == 0 && upperOpen) {
          return false;
        }
      }

      return true;
    });
  } else {
    throw 'keyPath $keyPath not supported';
  }
}

sembast.Filter _singleFieldKeyNotNullFilter(String keyPath) =>
    sembast.Filter.notEquals(keyPath, null);

sembast.Filter _singleFieldKeyEqualsFilter(String keyPath, dynamic key) =>
    sembast.Filter.equals(keyPath, key);

@Deprecated('Dev only')
// ignore: unused_element
sembast.Filter _debugSingleFieldNotNullFilter(String keyPath) =>
    sembast.Filter.and([
      sembast.Filter.notEquals(keyPath, true),
      sembast.Filter.notEquals(keyPath, false),
      _singleFieldKeyNotNullFilter(keyPath)
    ]);

@Deprecated('Dev only')
// ignore: unused_element
sembast.Filter _debugSingleFieldKeyEqualsFilter(String keyPath, dynamic key) =>
    sembast.Filter.equals(keyPath, key);

final singleFieldKeyEqualsFilter = _singleFieldKeyEqualsFilter;
final singleFieldKeyNotNullFilter = _singleFieldKeyNotNullFilter;
// final singleFieldKeyEqualsFilter = _debugSingleFieldKeyEqualsFilter;
// final singleFieldKeyNotNullFilter = _debugSingleFieldNotNullFilter;

/// for composite or not
sembast.Filter storeKeyFilter(Object? keyPath, Object key) {
  return keyFilter(keyPath, key);
}

/// The null value for the key actually means any but null...
/// Key path must have been escaped before
sembast.Filter keyFilter(dynamic keyPath, Object? key,
    [bool multiEntry = false]) {
  if (keyPath is String) {
    if (multiEntry) {
      return sembast.Filter.custom((snapshot) {
        // We support array too!
        var value = snapshot[keyPath];
        if (value is List) {
          if (key == null) {
            return value.isNotEmpty;
          } else {
            return value.contains(key);
          }
        } else {
          if (key == null) {
            return value != null;
          } else {
            return value == key;
          }
        }
      });
    } else {
      if (key == null) {
        // key must not be nulled
        return singleFieldKeyNotNullFilter(keyPath);
      }
      return singleFieldKeyEqualsFilter(keyPath, key);
    }
  } else if (keyPath is List) {
    final keyList = keyPath;
    // No constraint on the key it just needs to exist
    // so every field must be non-null
    if (key == null) {
      return sembast.Filter.and(List.generate(
          keyList.length, (i) => keyFilter(keyList[i], null, multiEntry)));
    } else {
      // The key must be a list too...
      if (key is List) {
        final valueList = key;
        return sembast.Filter.and(List.generate(keyList.length,
            (i) => keyFilter(keyList[i], valueList[i], multiEntry)));
      } else {
        // Always false
        return sembast.Filter.custom((record) => false);
      }
    }
  }
  throw 'keyPath $keyPath not supported';
}

sembast.Filter keyOrRangeFilter(
    dynamic keyPath, dynamic keyOrRange, bool multiEntry) {
  if (keyOrRange is KeyRange) {
    return keyRangeFilter(keyPath, keyOrRange, multiEntry);
  } else {
    return keyFilter(keyPath, keyOrRange, multiEntry);
  }
}

sembast.Filter keyNotNullFilter(dynamic keyPath) {
  if (keyPath is String) {
    return sembast.Filter.notEquals(keyPath, null);
  } else if (keyPath is List) {
    final keyList = keyPath;
    return sembast.Filter.and(List.generate(keyList.length,
        (i) => sembast.Filter.notEquals(keyList[i] as String, null)));
  }
  throw 'keyPath $keyPath not supported';
}
