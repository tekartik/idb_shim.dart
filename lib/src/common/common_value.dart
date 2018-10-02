library idb_shim_common_value;

import 'dart:convert';

import 'package:idb_shim/idb.dart';

import '../client/error.dart';

// for now use JSON
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

dynamic decodeValue(dynamic value) {
  if (value == null) {
    return null;
  }
  return json.decode(value as String);
}

dynamic encodeKey(dynamic key) {
  return key;
}

dynamic decodeKey(dynamic key) {
  return key;
}

List _cloneList(List original) {
  if (original == null) {
    return null;
  }
  List list = List();
  original.forEach((value) {
    list.add(_cloneValue(value));
  });
  return list;
}

Map _cloneMap(Map original) {
  Map map = Map();
  original.forEach((key, value) {
    map[key] = _cloneValue(value);
  });
  return map;
}

dynamic _cloneValue(dynamic original) {
  if (original is Map) {
    return _cloneMap(original);
  } else if (original is List) {
    return _cloneList(original);
  }
  // assume immutable
  return original;
}

dynamic cloneValue(dynamic value, [String keyPath, dynamic key]) {
  dynamic clone = _cloneValue(value);
  if (keyPath != null) {
    // assume map
    clone[keyPath] = key;
  }
  return clone;
}

// handle single object and array!
int compareKeys<T>(T first, T second) {
  if (first is num && second is num) {
    return first < second ? -1 : (first == second ? 0 : 1);
  } else if (first is String && second is String) {
    int compare = first.compareTo(second);
    return compare < 0 ? -1 : (compare == 0 ? 0 : 1);
  } else if (first is List && second is List) {
    for (int i = 0; i < first.length; i++) {
      int compare = compareKeys(first[i], second[i]);
      if (compare != 0) {
        return compare;
      }
    }
    return 0;
  }
  //print(first.runtimeType);
  throw DatabaseInvalidKeyError(first);
}

// when keyPath is an array
// Return the relevant keyPath at index
KeyRange keyArrayRangeAt(KeyRange keyRange, int index) {
  _valueAt(List value, int index) {
    return value == null ? null : value[index];
  }

  return KeyRange.bound(
      _valueAt(keyRange.lower as List, index),
      _valueAt(keyRange.upper as List, index),
      keyRange.lowerOpen,
      keyRange.upperOpen);
}

// return a list if keyPath is an array
dynamic mapValueAtKeyPath(Map map, keyPath) {
  if (keyPath is String) {
    return map[keyPath];
  } else if (keyPath is List) {
    List keyList = keyPath;
    return List.generate(keyList.length, (i) => map[keyList[i]]);
  }
  throw 'keyPath $keyPath not supported';
}
