library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/utils/env_utils.dart';
import 'package:sembast/blob.dart';
import 'package:sembast/timestamp.dart';

/// encode a value using JSON.
Object? encodeValue(Object? value) {
  if (value == null) {
    return null;
  }
  return json.encode(value);
  //  return JSON.encode(value, toEncodable: (nonEncodable) {
  //    //throw new JsonUnsupportedObjectError(nonEncodable, cause: "Cannot convert $nonEncodable (type: ${nonEncodable.runtimeType})");
  //    if (nonEncodable is DateTime) {
  //      return nonEncodable.toIso8601String();
  //    }
  //    return nonEncodable;
  //  });
}

/// decode a value from JSON.
Object? decodeValue(Object? value) {
  if (value == null) {
    return null;
  }
  return json.decode(value as String);
}

/// Encode a key.
Object encodeKey(Object key) {
  return key;
}

/// Decode a key.
Object decodeKey(Object key) {
  return key;
}

List<T> _cloneList<T>(List<T> original) {
  final list = <T>[];
  for (var value in original) {
    list.add(_cloneValue(value) as T);
  }
  return list;
}

/// Deep clone a map
Map<String, Object?> cloneMap(Map original) => _cloneMap(original);

Map<String, Object?> _cloneMap(Map original) {
  final map = <String, Object?>{};
  original.forEach((key, value) {
    map[key as String] = _cloneValue(value);
  });
  return map;
}

Object? _cloneValue(Object? original) {
  if (original is Map) {
    return _cloneMap(original);
  } else if (original is List) {
    return _cloneList(original);
  }
  // assume immutable
  return original;
}

/// Clone and add the key if needed
Object cloneValue(Object value, [String? keyPath, Object? key]) {
  var clone = _cloneValue(value)!;
  if (keyPath != null) {
    // assume map
    setMapFieldValue(clone as Map, keyPath, key as Object);
  }
  return clone;
}

/// Fix compare value according to sign
int fixCompareValue(int value, {bool asc = true}) {
  if (asc) {
    return value;
  } else {
    return -value;
  }
}

/// Rank of a key type in the IndexedDB key order (number < date < string <
/// binary < array), null if not a key type (array items are not checked).
///
/// DateTime keys are not supported (rejected by the key validation), a date
/// is only found as a stored value (sembast timestamp, like blob for binary).
int? _keyTypeRank(Object? key) {
  if (key is num) {
    return key.isNaN ? null : 0;
  } else if (key is Timestamp) {
    return 1;
  } else if (key is String) {
    return 2;
  } else if (key is Uint8List || key is ByteBuffer || key is Blob) {
    // Before List, an Uint8List is a List.
    return 3;
  } else if (key is List) {
    return 4;
  }
  return null;
}

/// True if [key] is a valid key for the comparison (number, stored date,
/// string, binary or an array of valid keys), for stored values that can be
/// anything.
bool isValidKey(Object? key) {
  var rank = _keyTypeRank(key);
  if (rank == 4) {
    for (var item in key as List) {
      if (!isValidKey(item)) {
        return false;
      }
    }
  }
  return rank != null;
}

List<int> _keyBytes(Object key) {
  if (key is Blob) {
    return key.bytes;
  } else if (key is ByteBuffer) {
    return key.asUint8List();
  }
  return key as Uint8List;
}

int _sign(int value) => value < 0 ? -1 : (value == 0 ? 0 : 1);

/// Compare 2 lists item by item, then by length.
int _compareLists<T>(List<T> first, List<T> second, int Function(T, T) cmp) {
  var length = first.length < second.length ? first.length : second.length;
  for (var i = 0; i < length; i++) {
    final compare = cmp(first[i], second[i]);
    if (compare != 0) {
      return compare;
    }
  }
  return _sign(first.length - second.length);
}

/// Compare keys in the IndexedDB order: number < date < string < binary <
/// array, arrays (and binaries) compared item by item, then by length.
///
/// Keys are assumed valid (checked before), throws a [DatabaseInvalidKeyError]
/// on a type that is not a key.
int compareKeys(Object? first, Object? second) {
  var firstRank = _keyTypeRank(first);
  var secondRank = _keyTypeRank(second);
  if (firstRank == null || secondRank == null) {
    throw DatabaseInvalidKeyError([first, second]);
  }
  if (firstRank != secondRank) {
    return firstRank < secondRank ? -1 : 1;
  }
  switch (firstRank) {
    case 0:
      var firstNum = first as num;
      var secondNum = second as num;
      return firstNum < secondNum ? -1 : (firstNum == secondNum ? 0 : 1);
    case 1:
      return _sign((first as Timestamp).compareTo(second as Timestamp));
    case 2:
      return _sign((first as String).compareTo(second as String));
    case 3:
      return _compareLists<int>(
        _keyBytes(first!),
        _keyBytes(second!),
        (a, b) => _sign(a - b),
      );
    default:
      return _compareLists<Object?>(first as List, second as List, compareKeys);
  }
}

/// Like [compareKeys] but null if a key is not valid (stored values).
int? compareKeysOrNull(Object? first, Object? second) {
  if (!isValidKey(first) || !isValidKey(second)) {
    return null;
  }
  return compareKeys(first, second);
}

/// True if [key] is in [range] (IndexedDB key order), false for an invalid
/// key. The range bounds are assumed valid.
bool keyRangeContainsKey(KeyRange range, Object? key) {
  if (!isValidKey(key)) {
    return false;
  }
  var lower = range.lower;
  if (lower != null) {
    var cmp = compareKeys(key, lower);
    if (cmp < 0 || (cmp == 0 && range.lowerOpen)) {
      return false;
    }
  }
  var upper = range.upper;
  if (upper != null) {
    var cmp = compareKeys(key, upper);
    if (cmp > 0 || (cmp == 0 && range.upperOpen)) {
      return false;
    }
  }
  return true;
}

/// True if [key] matches [keyOrRange]: in the range, equal to the key, or any
/// valid key when null.
bool keyMatchesKeyOrRange(Object? key, Object? keyOrRange) {
  if (keyOrRange is KeyRange) {
    return keyRangeContainsKey(keyOrRange, key);
  } else if (keyOrRange == null) {
    return isValidKey(key);
  }
  // keyOrRange is assumed valid
  return isValidKey(key) && compareKeys(key, keyOrRange) == 0;
}

/// when keyPath is an array
/// Return the relevant keyPath at index
KeyRange compositeKeyRangeAt(KeyRange keyRange, int index) {
  var lower = keyRange.lower;
  var upper = keyRange.upper;

  if (lower is List) {
    if (upper is List) {
      return KeyRange.bound(
        lower[index] as Object,
        upper[index] as Object,
        keyRange.lowerOpen,
        keyRange.upperOpen,
      );
    }
    return KeyRange.lowerBound(lower[index] as Object, keyRange.lowerOpen);
  }
  return KeyRange.upperBound(
    (upper as List)[index] as Object,
    keyRange.upperOpen,
  );
}

/// return a list if keyPath is an array
///
/// if [keyPath] is a, the list cannot contain null values and null is returned instead.
Object? mapValueAtKeyPath(Map? map, Object? keyPath) {
  return map?.getKeyValue(keyPath);
}

/// Convert a single value or an iterable to a list
Set<Object?>? valueAsSet(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Iterable) {
    return Set.from(value);
  }
  return {value};
}

@Deprecated('Use valueAsSet')
/// Deprecated: Use valueAsSet
Set? valueAsKeySet(Object? value) => valueAsSet(value);

/// Convert a single value or an iterable to a list
List? valueAsList(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is List) {
    return value;
  }
  if (value is Iterable) {
    return value.toList();
  }
  return [value];
}

/// Split a filed by its dot (.) to get a part
List<String> getFieldParts(String field) => field.split('.');

/// Get map field helper.
T? getMapFieldValue<T>(Map? map, String field) {
  return map?.getFieldValue(field);
}

/// Get deep map member value.
T? getPartsMapValue<T>(Map? map, Iterable<String> parts) {
  Object? value = map;
  for (final part in parts) {
    if (value is Map) {
      value = value[part];
    } else {
      return null;
    }
  }
  return value as T?;
}

/// Set a field value.
void setMapFieldValue(Map map, String field, Object? value) {
  setPartsMapValue(map, getFieldParts(field), value);
}

/// Set a a deep map member value
void setPartsMapValue(Map map, List<String> parts, Object? value) {
  for (var i = 0; i < parts.length - 1; i++) {
    final part = parts[i];
    Object? sub = map[part];
    if (sub is! Map) {
      sub = <String, Object?>{};
      map[part] = sub;
    }
    map = sub;
  }
  var key = parts.last;
  map[key] = value;
}

/// Common extension
extension IdbValueMapExt on Map {
  /// return a list if keyPath is an array
  ///
  /// if [keyPath] is a, the list cannot contain null values and null is returned instead.
  Object? getKeyValue(Object? keyPath) {
    if (keyPath is String) {
      return getFieldValue(keyPath);
    } else if (keyPath is List) {
      final keyList = keyPath;
      var keys = List<Object?>.generate(
        keyList.length,
        (i) => getFieldValue(keyPath[i] as String),
      );
      if (keys.where((element) => element == null).isNotEmpty) {
        /// the list cannot contain null values
        return null;
      }
      return keys;
    }
    throw ArgumentError('keyPath $keyPath not supported');
  }

  /// return a list if keyPath is an array
  ///
  /// if [keyPath] is a, the list cannot contain null values and null is returned instead.
  void setKeyValue(Object? keyPath, Object value) {
    if (keyPath is String) {
      return setFieldValue(keyPath, value);
    } else if (keyPath is List) {
      final keyList = keyPath;
      if (isDebug) {
        if (value is! List) {
          throw ArgumentError.value(value, 'key value', 'is not a list');
        }
        if (keyPath is! List<String>) {
          throw ArgumentError.value(
            keyPath,
            'keyPath',
            'is not a list of string',
          );
        }
        if (value.length != keyList.length) {
          throw ArgumentError.value(
            '$keyPath: $value',
            'keyPath: value',
            'length do not match (${keyList.length} vs ${value.length}',
          );
        }
      }

      /// value must be a list

      final valueList = value as List<Object?>;
      assert(keyList.length == valueList.length);
      for (var i = 0; i < keyList.length; i++) {
        setFieldValue(keyList[i] as String, valueList[i]!);
      }
    } else {
      throw ArgumentError('keyPath $keyPath not supported');
    }
  }

  /// Get map field helper.
  T? getFieldValue<T>(String field) {
    return getPartsMapValue<T>(this, getFieldParts(field));
  }

  /// Set a field value.
  void setFieldValue(String field, Object? value) {
    setPartsMapValue(this, getFieldParts(field), value);
  }
}

/// Compare two sets for value equality
bool valueSetEquals<T>(Set<T>? a, Set<T>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (final value in a) {
    if (!b.contains(value)) {
      return false;
    }
  }
  return true;
}

/// Compare two sets for value equality
bool valueListEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// The count of an idb getAll/getAllKeys, null (unlimited) for null or 0 as
/// in the IndexedDB spec.
int? idbGetAllCountOrNull(int? count) =>
    (count == null || count <= 0) ? null : count;
