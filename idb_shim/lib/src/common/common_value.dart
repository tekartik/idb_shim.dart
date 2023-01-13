library idb_shim_common_value;

import 'dart:convert';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/utils/env_utils.dart';

/// encode a value using JSON.
dynamic encodeValue(dynamic value) {
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

Map _cloneMap(Map original) {
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

/// Compare keys, handle single object and array!
int compareKeys(dynamic first, dynamic second) {
  if (first is num && second is num) {
    return first < second ? -1 : (first == second ? 0 : 1);
  } else if (first is String && second is String) {
    final compare = first.compareTo(second);
    return compare < 0 ? -1 : (compare == 0 ? 0 : 1);
  } else if (first is List && second is List) {
    for (var i = 0; i < first.length; i++) {
      final compare = compareKeys(first[i], second[i]);
      if (compare != 0) {
        return compare;
      }
    }
    return 0;
  }
  //print(first.runtimeType);
  throw DatabaseInvalidKeyError([first, second]);
}

/// when keyPath is an array
/// Return the relevant keyPath at index
KeyRange compositeKeyRangeAt(KeyRange keyRange, int index) {
  var lower = keyRange.lower;
  var upper = keyRange.upper;

  if (lower is List) {
    if (upper is List) {
      return KeyRange.bound(lower[index] as Object, upper[index] as Object,
          keyRange.lowerOpen, keyRange.upperOpen);
    }
    return KeyRange.lowerBound(lower[index] as Object, keyRange.lowerOpen);
  }
  return KeyRange.upperBound(
      (upper as List)[index] as Object, keyRange.upperOpen);
}

/// return a list if keyPath is an array
///
/// if [keyPath] is a, the list cannot contain null values and null is returned instead.
Object? mapValueAtKeyPath(Map? map, Object? keyPath) {
  return map?.getKeyValue(keyPath);
}

/// Convert a single value or an iterable to a list
Set<Object?>? valueAsSet(dynamic value) {
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
Set? valueAsKeySet(dynamic value) => valueAsSet(value);

/// Convert a single value or an iterable to a list
List? valueAsList(dynamic value) {
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
  dynamic value = map;
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
    dynamic sub = map[part];
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
          keyList.length, (i) => getFieldValue(keyPath[i] as String));
      if (keys.where((element) => element == null).isNotEmpty) {
        /// the list cannot contain null values
        return null;
      }
      return keys;
    }
    throw 'keyPath $keyPath not supported';
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
              keyPath, 'keyPath', 'is not a list of string');
        }
        if (value.length != keyList.length) {
          throw ArgumentError.value('$keyPath: $value', 'keyPath: value',
              'length do not match (${keyList.length} vs ${value.length}');
        }
      }

      /// value must be a list

      final valueList = value as List<Object?>;
      assert(keyList.length == valueList.length);
      for (var i = 0; i < keyList.length; i++) {
        setFieldValue(keyList[i] as String, valueList[i]!);
      }
    } else {
      throw 'keyPath $keyPath not supported';
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
