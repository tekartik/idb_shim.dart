// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sembast/sembast_import.dart' as sembast;

/// keyPath must have been escaped before
sembast.Filter keyCursorFilter(
  Object? keyPath,
  Object? key,
  KeyRange? range,
  bool multiEntry,
) {
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

// return <0 if value1 < value2 or >0 if greater (IndexedDB key order)
// returns 0 if cannot be compared or equals
int compareValue(Object? value1, Object? value2) =>
    compareKeysOrNull(value1, value2) ?? 0;

// Matches if <0
int lowerCompareSingleValue(Object? lower, Object? value) {
  if (value == null) {
    // failure for matches
    return 1;
  }
  return compareValue(lower, value);
}

// Matches if <0
int? lowerCompareValue(Object? lower, Object? value, bool multiEntry) {
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
bool lowerMatchesSingleValue(Object? lower, bool lowerOpen, Object? value) {
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
int upperCompareSingleValue(Object? upper, Object? value) {
  if (value == null) {
    // failure for matches
    return -1;
  }
  return compareValue(upper, value);
}

// Matches if >0
int? upperCompareValue(Object? lower, Object? value, bool multiEntry) {
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
bool upperMatchesSingleValue(Object? upper, bool upperOpen, Object? value) {
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
  Object? lower,
  bool lowerOpen,
  Object? value,
  bool multiEntry,
) {
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
  Object? upper,
  bool upperOpen,
  Object? value,
  bool multiEntry,
) {
  if (multiEntry && value is List) {
    for (var item in value) {
      if (upperMatchesSingleValue(upper, upperOpen, item)) {
        return true;
      }
    }
    return false;
  }
  return upperMatchesSingleValue(upper, upperOpen, value);
}

/// The valid keys of a record value for [keyPath], [getField] reading a field
/// value: the value at the key path, the list of the values at each key path
/// for an array key path, or each distinct item for a [multiEntry] array value
/// (an entry per key).
///
/// keyPath must have been escaped before.
Iterable<Object> keyPathKeys(
  Object? Function(String field) getField,
  Object keyPath,
  bool multiEntry,
) sync* {
  if (keyPath is String) {
    var value = getField(keyPath);
    if (multiEntry && value is List) {
      var keys = <Object>[];
      for (var item in value) {
        if (isValidKey(item) &&
            !keys.any((key) => compareKeysOrNull(key, item) == 0)) {
          keys.add(item as Object);
        }
      }
      yield* keys;
    } else if (isValidKey(value)) {
      yield value!;
    }
  } else if (keyPath is List) {
    final values = List<Object?>.generate(
      keyPath.length,
      (i) => getField(keyPath[i] as String),
    );
    if (isValidKey(values)) {
      yield values;
    }
  } else {
    throw ArgumentError('keyPath $keyPath not supported');
  }
}

/// The valid keys of a record for [keyPath], see [keyPathKeys].
Iterable<Object> recordKeyPathKeys(
  sembast.RecordSnapshot snapshot,
  Object keyPath,
  bool multiEntry,
) => keyPathKeys((field) => snapshot[field], keyPath, multiEntry);

/// Matches records having a key (an entry for a [multiEntry] index) in
/// [range], in the IndexedDB key order.
sembast.Filter keyRangeFilter(
  Object? keyPath,
  KeyRange range,
  bool multiEntry,
) {
  keyPath ??= sembast.Field.key;
  return sembast.Filter.custom(
    (snapshot) => recordKeyPathKeys(
      snapshot,
      keyPath!,
      multiEntry,
    ).any((key) => keyRangeContainsKey(range, key)),
  );
}

sembast.Filter _singleFieldKeyNotNullFilter(String keyPath) =>
    sembast.Filter.notEquals(keyPath, null);

sembast.Filter _singleFieldKeyEqualsFilter(String keyPath, Object? key) =>
    sembast.Filter.equals(keyPath, key);

@Deprecated('Dev only')
// ignore: unused_element
sembast.Filter _debugSingleFieldNotNullFilter(String keyPath) =>
    sembast.Filter.and([
      sembast.Filter.notEquals(keyPath, true),
      sembast.Filter.notEquals(keyPath, false),
      _singleFieldKeyNotNullFilter(keyPath),
    ]);

@Deprecated('Dev only')
// ignore: unused_element
sembast.Filter _debugSingleFieldKeyEqualsFilter(String keyPath, Object? key) =>
    sembast.Filter.equals(keyPath, key);

const singleFieldKeyEqualsFilter = _singleFieldKeyEqualsFilter;
const singleFieldKeyNotNullFilter = _singleFieldKeyNotNullFilter;
// final singleFieldKeyEqualsFilter = _debugSingleFieldKeyEqualsFilter;
// final singleFieldKeyNotNullFilter = _debugSingleFieldNotNullFilter;

/// for composite or not
sembast.Filter storeKeyFilter(Object? keyPath, Object key) {
  return keyFilter(keyPath, key);
}

/// The null value for the key actually means any valid key.
/// Key path must have been escaped before
sembast.Filter keyFilter(
  Object? keyPath,
  Object? key, [
  bool multiEntry = false,
]) {
  if (keyPath is! String && keyPath is! List) {
    throw ArgumentError('keyPath $keyPath not supported');
  }
  return sembast.Filter.custom(
    (snapshot) => recordKeyPathKeys(
      snapshot,
      keyPath!,
      multiEntry,
    ).any((recordKey) => keyMatchesKeyOrRange(recordKey, key)),
  );
}

sembast.Filter keyOrRangeFilter(
  Object? keyPath,
  Object? keyOrRange,
  bool multiEntry,
) {
  if (keyOrRange is KeyRange) {
    return keyRangeFilter(keyPath, keyOrRange, multiEntry);
  } else {
    return keyFilter(keyPath, keyOrRange, multiEntry);
  }
}

sembast.Filter keyNotNullFilter(Object? keyPath) {
  if (keyPath is String) {
    return sembast.Filter.notEquals(keyPath, null);
  } else if (keyPath is List) {
    final keyList = keyPath;
    return sembast.Filter.and(
      List.generate(
        keyList.length,
        (i) => sembast.Filter.notEquals(keyList[i] as String, null),
      ),
    );
  }
  throw ArgumentError('keyPath $keyPath not supported');
}
