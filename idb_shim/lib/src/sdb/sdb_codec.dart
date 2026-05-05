import 'package:idb_shim/src/sdb/sdb_utils.dart';
import 'package:idb_shim/src/utils/env_utils.dart';
import 'package:sembast/utils/type_adapter.dart';

import 'sdb.dart';

/// Optional codec to use when opening a database
class SdbCodec {
  /// No transformation is used, data is store as is
  /// Ensure that you only save compatible data:
  /// - bool
  /// - num
  /// - String
  /// - List
  /// - Map
  static final none = _SdbCodecNone();

  /// Default codec that supports SdbTimestamp and SdbBlob
  static final defaultCodec = _SdbCodecDefault();
}

/// Private extension
extension SdbCodecPrvExt on SdbCodec {
  SdbCodecInterface get _interface => this as SdbCodecInterface;

  /// Encode a value
  Object encode(Object value) => _interface.encode(value);

  /// Decode a value
  T decode<T>(Object value) => _interface.decode<T>(value);

  /// Encode a value (not a map nor a or list), good for key
  /// when the value is the direct adapter value
  Object encodeKeyValue(Object value) => _interface.encodeKeyValue(value);

  /// Decode a value (not a map nor a or list), good for key
  /// when the value is the direct adapter value
  T decodeKeyValue<T>(Object value) => _interface.decodeKeyValue<T>(value);
}

/// Private interface
abstract class SdbCodecInterface {
  /// Encode a value (not a map nor a or list), good for key
  /// when the value is the direct adapter value
  Object encodeKeyValue(Object value);

  /// Decode a value (not a map nor a or list), good for key
  /// when the value is the direct adapter value
  T decodeKeyValue<T>(Object value);

  /// Encode a value
  Object encode(Object value);

  /// Decode a value
  T decode<T>(Object value);

  /// Fix sdb key path for the given type
  String sdbKeyPath<I>(String keyPath);
}

class _SdbCodecNone implements SdbCodec, SdbCodecInterface {
  @override
  Object encode(Object value) => value;
  @override
  T decode<T>(Object value) => value as T;

  @override
  Object encodeKeyValue(Object value) => value;

  @override
  T decodeKeyValue<T>(Object value) => value as T;

  @override
  String sdbKeyPath<I>(String keyPath) => keyPath;
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

class _SdbCodecDefault extends _SdbCodecWithAdapters {
  _SdbCodecDefault() : super(adapters: sembastDefaultTypeAdapters);
}

abstract class _SdbCodecWithAdapters implements SdbCodec, SdbCodecInterface {
  final List<SembastTypeAdapter<Object, String>> adapters;
  late final _adapterMap = () {
    var map = <String, SembastTypeAdapter<Object, String>>{
      for (var adapter in adapters) adapter.name: adapter,
    };
    return map;
  }();

  final _adapterTypeMap = <Type, SembastTypeAdapter<Object, Object>>{
    SdbTimestamp: sembastTimestampAdapter,
    SdbBlob: sembastBlobAdapter,
  };

  @override
  String sdbKeyPath<I>(String keyPath) {
    var adapter = getAdapterForType<I>();
    if (adapter != null) {
      return '$keyPath.${adapter.mapKey}';
    } else {
      return keyPath;
    }
  }

  /// Get adapter for type
  SembastTypeAdapter<T, Object>? getAdapterForType<T>() {
    return _adapterTypeMap[T] as SembastTypeAdapter<T, Object>?;
  }

  _SdbCodecWithAdapters({required this.adapters});

  /// Sdb to idb value with type adapter support
  Object? sdbToIdbSimpleKeyValueOrNull(Object? value) {
    if (isBasicIdbTypeOrNull(value)) {
      return value;
    }
    for (var adapter in adapters) {
      if (adapter.isType(value)) {
        return adapter.encode(value!);
      }
    }
    throw ArgumentError.value(value);
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

  /// Sdb to idb value with type adapter support
  Object? sdbToIdbValueOrNull(Object? value) {
    if (isBasicIdbTypeOrNull(value)) {
      return value;
    } else if (value is Map) {
      var map = value;
      Map? clone;
      if (value is! SdbModel) {
        clone = SdbModel();
      }
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
    for (var adapter in adapters) {
      if (adapter.isType(value)) {
        return <String, Object?>{adapter.mapKey: adapter.encode(value!)};
      }
    }
    throw ArgumentError.value(value);
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

  @override
  Object encodeKeyValue(Object value) {
    return sdbToIdbSimpleKeyValueOrNull(value)!;
  }

  @override
  T decodeKeyValue<T>(Object value) {
    return idbToSdbSimpleKeyValueOrNull<T>(value)!;
  }

  @override
  Object encode(Object value) {
    return sdbToIdbValueOrNull(value)!;
  }

  @override
  T decode<T>(Object value) {
    return idbToSdbValueOrNull(value) as T;
  }
}
