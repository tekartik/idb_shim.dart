library idb_shim.common_validation;

import '../../idb_client.dart';

void checkKeyParam(var key) {
  if (key == null) {
    throw new DatabaseNoKeyError();
  }
  if (!(key is String || key is num)) {
    throw new DatabaseInvalidKeyError(key);
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
