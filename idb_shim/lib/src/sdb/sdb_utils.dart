import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/utils/env_utils.dart';
import 'package:sembast/utils/type_adapter.dart';

import 'sdb_types.dart';

/// Find records descending argument to idb direction.
String descendingToIdbDirection(bool? descending) {
  return (descending ?? false) ? idbDirectionPrev : idbDirectionNext;
}

/// True for null, num, String, bool
bool isBasicIdbTypeOrNull(Object? value) {
  if (value == null) {
    return true;
  } else if (value is num ||
      value is String ||
      value is bool ||
      value is DateTime ||
      value is Uint8List) {
    return true;
  }
  return false;
}

final _adapters = sembastDefaultTypeAdapters;
final _adapterMap = () {
  var map = <String, SembastTypeAdapter<Object, String>>{
    for (var adapter in _adapters) adapter.name: adapter,
  };
  return map;
}();

/// Sdb to idb value with type adapter support
Object? sdbToIdbValueOrNull(Object? value) {
  if (isBasicIdbTypeOrNull(value)) {
    return value;
  } else if (value is Map) {
    var map = value;
    Map? clone;
    map.forEach((key, item) {
      var converted = sdbToIdbValueOrNull(item);
      if (!identical(converted, item)) {
        clone ??= Map<String, Object?>.from(map);
        clone![key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is List) {
    var list = value;
    List? clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      var converted = sdbToIdbValueOrNull(item);
      if (!identical(converted, item)) {
        clone ??= List.from(list);
        clone[i] = converted;
      }
    }
    return clone ?? list;
  }
  for (var adapter in _adapters) {
    if (adapter.isType(value)) {
      return <String, Object?>{'@${adapter.name}': adapter.encode(value!)};
    }
  }
  throw ArgumentError.value(value);
}

/// Sdb to idb for non null values
Object sdbToIdbValue(Object value) {
  return sdbToIdbValueOrNull(value)!;
}

/// Idb to sdb value
Object? idbToSdbValueOrNull(Object? value) {
  if (isBasicIdbTypeOrNull(value)) {
    return value;
  } else if (value is Map) {
    var map = value;
    if (_looksLikeCustomType(map)) {
      var type = (map.keys.first as String).substring(1);
      if (type == '') {
        return map.values.first as Object;
      }
      var adapter = _adapterMap[type];
      if (adapter != null) {
        var encodedValue = value.values.first;
        try {
          return adapter.decode(encodedValue.toString());
        } catch (e) {
          if (isDebug) {
            // ignore: avoid_print
            print('$e - ignoring $encodedValue ${encodedValue.runtimeType}');
          }
        }
      }
    }
    Map? clone;
    map.forEach((key, item) {
      var converted = idbToSdbValueOrNull(item);
      if (!identical(converted, item)) {
        clone ??= Map<String, Object?>.from(map);
        clone![key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is List) {
    var list = value;
    List? clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      var converted = idbToSdbValueOrNull(item);
      if (!identical(converted, item)) {
        clone ??= List.from(list);
        clone[i] = converted;
      }
    }
    return clone ?? list;
  }
  throw ArgumentError.value(value);
}

/// Idb to sdb for non null values
V idbToSdbValue<V>(Object value) {
  var result = idbToSdbValueOrNull(value)!;
  if (result is Map && result is! SdbModel) {
    result = result.cast<String, Object?>();
  }
  return result as V;
}

// Look like custom?
bool _looksLikeCustomType(Map map) {
  if (map.length == 1) {
    var key = map.keys.first;
    if (key is String) {
      return key.startsWith('@');
    }
    throw ArgumentError.value(key);
  }
  return false;
}

/// Clone a value.
Object? idbCloneValueOrNull(Object? value) {
  if (isBasicIdbTypeOrNull(value)) {
    return value;
  }
  if (value is Map) {
    return value.map<String, Object?>(
      (key, value) => MapEntry(key as String, idbCloneValueOrNull(value)),
    );
  }
  if (value is Iterable) {
    return value.map((value) => idbCloneValueOrNull(value)).toList();
  }
  return value;
}

/// Clone a value.
SdbValue idbCloneValue(SdbValue value) {
  return idbCloneValueOrNull(value)!;
}
