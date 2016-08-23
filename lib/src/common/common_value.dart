library idb_shim_common_value;

import 'dart:convert';

import '../client/error.dart';

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

// handle single object and array!
int compareKeys(dynamic first, dynamic second) {
  if (first is num) {
    return first < second ? -1 : (first == second ? 0 : 1);
  } else if (first is String) {
    int compare = first.compareTo(second);
    return compare < 0 ? -1 : (compare == 0 ? 0 : 1);
  } else if (first is List) {
    for (int i = 0; i < first.length; i++) {
      int compare = compareKeys(first[i], second[i]);
      if (compare != 0) {
        return compare;
      }
    }
    return 0;
  }
  //print(first.runtimeType);
  throw new DatabaseInvalidKeyError(first);
}