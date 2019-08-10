library idb_shim.common_validation;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_error.dart';
import 'package:idb_shim/src/common/common_value.dart';

void checkKeyParam(var key) {
  if (key == null) {
    throw DatabaseNoKeyError();
  }
  if (!(key is String || key is num)) {
    if (key is List && key.isNotEmpty) {
      List keyList = key;
      for (var item in keyList) {
        checkKeyParam(item);
      }
      return;
    }
    throw DatabaseInvalidKeyError(key);
  }
}

void checkKeyValueParam(
    {String keyPath, dynamic key, dynamic value, bool autoIncrement}) {
  if (key != null) {
    checkKeyParam(key);
    if (keyPath != null) {
      // Cannot have both
      throw DatabaseNoKeyExpectedError();
    }
  } else {
    if (!(value is Map &&
        keyPath != null &&
        mapValueAtKeyPath(value, keyPath) != null)) {
      if (!(autoIncrement ?? false)) {
        if (key == null) {
          throw new DatabaseMissingKeyError();
        } else {
          throw DatabaseMissingInlineKeyError();
        }
      }
    }
  }
}
