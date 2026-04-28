import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_validation.dart';
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
