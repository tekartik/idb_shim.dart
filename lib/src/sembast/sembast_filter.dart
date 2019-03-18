import 'dart:math';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/sembast/sembast_import.dart' as sdb;

/// keyPath must have been escaped before
sdb.Filter keyCursorFilter(
    dynamic keyPath, key, KeyRange range, bool multiEntry) {
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
// returns null if cannot be compared
int compareValue(dynamic value1, dynamic value2) {
  try {
    if (value1 is Comparable && value2 is Comparable) {
      return Comparable.compare(value1, value2);
    } else if (value1 is List && value2 is List) {
      List list1 = value1;
      List list2 = value2;

      for (int i = 0; i < min(value1.length, value2.length); i++) {
        int cmp = compareValue(list1[i], list2[i]);
        if (cmp == 0) {
          continue;
        }
        return cmp;
      }
      // Same ? return the length diff if any
      return compareValue(list1.length, list2.length);
    }
  } catch (_) {}
  return null;
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
int lowerCompareValue(dynamic lower, dynamic value, bool multiEntry) {
  int bestCmp;
  if (multiEntry && value is List) {
    for (var item in value) {
      int cmp = lowerCompareSingleValue(lower, item);
      if (cmp < 0) {
        return cmp;
      } else if (cmp == 0) {
        bestCmp = 0;
      }
    }
  }
  int singleCmp = lowerCompareSingleValue(lower, value);
  if (singleCmp != null) {
    if (bestCmp != null) {
      return min(singleCmp, bestCmp);
    }
    return singleCmp;
  }
  return bestCmp;
}

// True if simple value matches lower bound
bool lowerMatchesSingleValue(dynamic lower, bool lowerOpen, dynamic value) {
  if (value != null) {
    int cmp = lowerCompareSingleValue(lower, value);
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
int upperCompareValue(dynamic lower, dynamic value, bool multiEntry) {
  int bestCmp;
  if (multiEntry && value is List) {
    for (var item in value) {
      int cmp = upperCompareSingleValue(lower, item);
      if (cmp > 0) {
        return cmp;
      } else if (cmp == 0) {
        bestCmp = 0;
      }
    }
  }
  int singleCmp = upperCompareSingleValue(lower, value);
  if (singleCmp != null) {
    if (bestCmp != null) {
      return max(singleCmp, bestCmp);
    }
    return singleCmp;
  }
  return bestCmp;
}

// True if simple value matches lower bound
bool upperMatchesSingleValue(dynamic upper, bool upperOpen, dynamic value) {
  if (value != null) {
    int cmp = upperCompareSingleValue(upper, value);
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

sdb.Filter keyRangeFilter(dynamic keyPath, KeyRange range, bool multiEntry) {
  if (keyPath is String) {
    return sdb.Filter.custom((snapshot) {
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
    var lowerList = range.lower as List;
    var upperList = range.upper as List;
    if (lowerList != null) {
      assert(lowerList.length == keyPathList.length,
          'keyPath and lower bound length must match');
    }
    if (upperList != null) {
      assert(upperList.length == keyPathList.length,
          'keyPath and upper bound length must match');
    }
    return sdb.Filter.custom((snapshot) {
      List values = List.generate(
          keyPathList.length, (i) => snapshot[keyPathList[i] as String]);

      // no null accepted
      for (var value in values) {
        if (value == null) {
          return false;
        }
      }

      bool lowerOpen = range.lowerOpen;

      if (lowerList != null) {
        int cmp;
        for (int i = 0; i < keyPathList.length; i++) {
          var value = values[i];
          var lower = lowerList[i];
          if (lower == null) {
            // matches!
            continue;
          } else {
            cmp = lowerCompareValue(lower, value, multiEntry);
            if (cmp > 0) {
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

      bool upperOpen = range.upperOpen;

      if (upperList != null) {
        int cmp;
        for (int i = 0; i < keyPathList.length; i++) {
          var value = values[i];
          var upper = upperList[i];
          if (upper == null) {
            // matches!
            continue;
          } else {
            cmp = upperCompareValue(upper, value, multiEntry);
            if (cmp < 0) {
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

/// The null value for the key actually means any but null...
/// Key path must have been escaped before
sdb.Filter keyFilter(dynamic keyPath, var key, bool multiEntry) {
  if (keyPath is String) {
    if (multiEntry) {
      return sdb.Filter.custom((snapshot) {
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
        return sdb.Filter.notEqual(keyPath, null);
      }
      return sdb.Filter.equal(keyPath, key);
    }
  } else if (keyPath is List) {
    List keyList = keyPath;
    // No constraint on the key it just needs to exist
    // so every field must be non-null
    if (key == null) {
      return sdb.Filter.and(List.generate(
          keyList.length, (i) => keyFilter(keyList[i], null, multiEntry)));
    } else {
      final valueList = key as List;
      return sdb.Filter.and(List.generate(keyList.length,
          (i) => keyFilter(keyList[i], valueList[i], multiEntry)));
    }
  }
  throw 'keyPath $keyPath not supported';
}

sdb.Filter keyOrRangeFilter(
    dynamic keyPath, dynamic keyOrRange, bool multiEntry) {
  if (keyOrRange is KeyRange) {
    return keyRangeFilter(keyPath, keyOrRange, multiEntry);
  } else {
    return keyFilter(keyPath, keyOrRange, multiEntry);
  }
}
