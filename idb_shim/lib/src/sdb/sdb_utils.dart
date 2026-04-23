import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_validation.dart';
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

/// Internal extension
extension SdbSembastTypeAdapter on SembastTypeAdapter {
  /// key in the converted map
  String get mapKey => '\$$name';
}

final _adapters = sembastDefaultTypeAdapters;
final _adapterMap = () {
  var map = <String, SembastTypeAdapter<Object, String>>{
    for (var adapter in _adapters) adapter.name: adapter,
  };
  return map;
}();

final _adapterTypeMap = <Type, SembastTypeAdapter<Object, Object>>{
  SdbTimestamp: sembastTimestampAdapter,
};

/// Get adapter for type
SembastTypeAdapter<T, Object>? getAdapterForType<T>() {
  return _adapterTypeMap[T] as SembastTypeAdapter<T, Object>?;
}

/// Is basic sdb type or null
bool isBasicSdbTypeOrNull(Object? value) {
  return isBasicIdbTypeOrNull(value);
}

/// Is basic sdb type
bool isBasicSdbType(Object? value) {
  if (value == null) {
    return false;
  }
  return isBasicIdbTypeOrNull(value);
}

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
      return <String, Object?>{adapter.mapKey: adapter.encode(value!)};
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
      // Works for $Type and @Type (compat)
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

/// Simple key value
I idbToSdbSimpleKeyValue<I>(Object? key) {
  return idbToSdbSimpleKeyValueOrNull<I>(key) as I;
}

/// Idb to sdb value
I? idbToSdbSimpleKeyValueOrNull<I>(Object? value) {
  if (value == null) {
    return null;
  }
  // single timestamp key
  var adapter = getAdapterForType<I>();
  if (adapter != null) {
    return adapter.decode(value.toString());
  }
  if (isBasicSdbType(value)) {
    return value as I;
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
      return key.startsWith(r'$') ||
          // compat
          key.startsWith('@');
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

/// Check an sdb index key param
bool sdbIsValidIndexKeyParam(Object? key) {
  if (isValidKeyParam(key)) {
    return true;
  }
  return (key is SdbTimestamp);
}

/// Check an sdb index key param
void sdbCheckIndexKeyParam(Object? key) {
  if (!sdbIsValidIndexKeyParam(key)) {
    throw DatabaseInvalidKeyError(key);
  }
}

/// sdb index key value to idb key value
Object sdbToIndexKeyValue(Object? value) {
  return sdbToIndexKeyValueOrNull(value)!;
}

/// Sdb to idb value with type adapter support
Object? sdbToIndexKeyValueOrNull(Object? value) {
  return sdbToSimpleValueOrNull(value);
}

/// Sdb to idb value with type adapter support
Object? sdbToSimpleValueOrNull(Object? value) {
  if (isBasicIdbTypeOrNull(value)) {
    return value;
  }
  for (var adapter in _adapters) {
    if (adapter.isType(value)) {
      return adapter.encode(value!);
    }
  }
  throw ArgumentError.value(value);
}
