import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast/timestamp.dart';

/// True for null, num, String, bool
bool isBasicTypeOrNull(dynamic value) {
  if (value == null) {
    return true;
  } else if (value is num || value is String || value is bool) {
    return true;
  }
  return false;
}

dynamic _toSembastValue(dynamic value) {
  if (isBasicTypeOrNull(value)) {
    return value;
  } else if (value is Map) {
    var map = value;
    var clone;
    map.forEach((key, item) {
      var converted = _toSembastValue(item);
      if (!identical(converted, item)) {
        clone ??= Map<String, dynamic>.from(map);
        clone[key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is Uint8List) {
    return Blob(value);
  } else if (value is List) {
    var list = value;
    var clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      var converted = _toSembastValue(item);
      if (!identical(converted, item)) {
        clone ??= List.from(list);
        clone[i] = converted;
      }
    }
    return clone ?? list;
  } else if (value is DateTime) {
    return Timestamp.fromDateTime(value);
  } else {
    throw ArgumentError.value(value);
  }
}

/// Convert a value to a sembast compatible value
dynamic toSembastValue(dynamic value) {
  dynamic converted;
  try {
    converted = _toSembastValue(value);
  } on ArgumentError catch (e) {
    throw ArgumentError.value(e.invalidValue,
        '${e.invalidValue.runtimeType} in $value', 'not supported');
  }

  /// Ensure root is Map<String, dynamic> if only Map
  if (converted is Map && !(converted is Map<String, dynamic>)) {
    converted = converted.cast<String, dynamic>();
  }
  return converted;
}

dynamic _fromSembastValue(dynamic value) {
  if (isBasicTypeOrNull(value)) {
    return value;
  } else if (value is Map) {
    var map = value;
    var clone;
    map.forEach((key, item) {
      var converted = _fromSembastValue(item);
      if (!identical(converted, item)) {
        clone ??= Map<String, dynamic>.from(map);
        clone[key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is List) {
    var list = value;
    var clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      var converted = _fromSembastValue(item);
      if (!identical(converted, item)) {
        clone ??= List.from(list);
        clone[i] = converted;
      }
    }
    return clone ?? list;
  } else if (value is Timestamp) {
    return value.toDateTime(isUtc: true);
  } else if (value is Blob) {
    return value.bytes;
  } else {
    throw ArgumentError.value(value);
  }
}

/// Convert a value from a sembast value
dynamic fromSembastValue(dynamic value) {
  dynamic converted;
  try {
    converted = _fromSembastValue(value);
  } on ArgumentError catch (e) {
    throw ArgumentError.value(e.invalidValue,
        '${e.invalidValue.runtimeType} in $value', 'not supported');
  }

  /// Ensure root is Map<String, dynamic> if only Map
  if (converted is Map && !(converted is Map<String, dynamic>)) {
    converted = converted.cast<String, dynamic>();
  }
  return converted;
}