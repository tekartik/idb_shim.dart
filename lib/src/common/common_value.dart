library common_value;

import 'dart:convert';

// for now use JSON
dynamic encodeValue(dynamic value) {
  if (value == null) {
    return null;
  }
  return JSON.encode(value);
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
  return JSON.decode(value);
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
  List list = new List();
  original.forEach((value) {
    list.add(_cloneValue(value));
  });
  return list;
}

Map _cloneMap(Map original) {
  Map map = new Map();
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

bool checkKeyValue(String keyPath, dynamic key, dynamic value) {
  if (key != null) {
    if (keyPath != null) {
      if (value[keyPath] != null) {
        return false;
      }
    }
  }
  return true;
}
