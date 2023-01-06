library idb_shim_common_value;

import 'dart:convert';

import 'package:idb_shim/idb.dart';

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

List _cloneList(List original) {
  final list = [];
  for (var value in original) {
    list.add(_cloneValue(value));
  }
  return list;
}

Map _cloneMap(Map original) {
  final map = {};
  original.forEach((key, value) {
    map[key] = _cloneValue(value);
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
Object cloneValue(Object value, [String? keyPath, dynamic key]) {
  var clone = _cloneValue(value)!;
  if (keyPath != null) {
    // assume map
    setMapFieldValue(clone as Map, keyPath, key);
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
  throw DatabaseInvalidKeyError(first);
}

/// when keyPath is an array
/// Return the relevant keyPath at index
KeyRange keyArrayRangeAt(KeyRange keyRange, int index) {
  Object? valueAt(List? value, int index) {
    return value == null ? null : value[index];
  }

  return KeyRange.bound(
      valueAt(keyRange.lower as List?, index),
      valueAt(keyRange.upper as List?, index),
      keyRange.lowerOpen,
      keyRange.upperOpen);
}

/// return a list if keyPath is an array
///
/// if [keyPath] is a, the list cannot contain null values and null is returned instead.
Object? mapValueAtKeyPath(Map? map, Object? keyPath) {
  if (keyPath is String) {
    return getMapFieldValue(map, keyPath);
  } else if (keyPath is List) {
    final keyList = keyPath;
    var keys = List.generate(
        keyList.length, (i) => getMapFieldValue(map, keyPath[i] as String));
    if (keys.where((element) => element == null).isNotEmpty) {
      /// the list cannot contain null values
      return null;
    }
    return keys;
  }
  throw 'keyPath $keyPath not supported';
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
  return getPartsMapValue(map, getFieldParts(field));
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
void setMapFieldValue<T>(Map map, String field, T value) {
  setPartsMapValue(map, getFieldParts(field), value);
}

/// Set a a deep map member value
void setPartsMapValue<T>(Map map, List<String> parts, value) {
  for (var i = 0; i < parts.length - 1; i++) {
    final part = parts[i];
    dynamic sub = map[part];
    if (sub is! Map) {
      sub = <String, Object?>{};
      map[part] = sub;
    }
    map = sub;
  }
  map[parts.last] = value;
}
