library idb_shim.common_validation;

import '../../idb_client.dart';

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

bool checkKeyValueParam(String keyPath, dynamic key, dynamic value) {
  if (key != null) {
    checkKeyParam(key);
    if (keyPath != null) {
      if (value[keyPath] != null) {
        return false;
      }
    }
  }
  return true;
}
