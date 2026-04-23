library;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/sdb/sdb.dart';
import 'package:idb_shim/src/common/common_error.dart';
import 'package:idb_shim/src/common/common_value.dart';

/// Check a primary key param
void checkKeyParam(Object? key) {
  if (!isValidKeyParam(key)) {
    throw DatabaseInvalidKeyError(key);
  }
}

/// Check a primary key param
bool isValidKeyParam(Object? key) {
  if (key == null) {
    return false;
  }
  if (key is String || key is num) {
    return true;
  }
  if (key is List && key.isNotEmpty) {
    final keyList = key;
    for (var item in keyList) {
      if (!isValidKeyParam(item)) {
        return false;
      }
    }
    return true;
  }
  return false;
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

/// Check a key
/// keyPath can be: `List<String>` | `String`
void checkKeyValueParam({
  Object? keyPath,
  Object? key,
  Object? value,
  bool? autoIncrement,
}) {
  if (key != null) {
    checkKeyParam(key);
    if (keyPath != null) {
      // Cannot have both
      throw DatabaseNoKeyExpectedError();
    }
  } else {
    if (!(value is Map &&
        keyPath != null &&
        value.getKeyValue(keyPath) != null)) {
      if (!(autoIncrement ?? false)) {
        if (key == null) {
          throw DatabaseMissingKeyError();
        } else {
          throw DatabaseMissingInlineKeyError();
        }
      }
    }
  }
}
