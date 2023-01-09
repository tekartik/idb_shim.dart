// ignore_for_file: public_member_api_docs

library idb_shim.common_validation;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_error.dart';
import 'package:idb_shim/src/common/common_value.dart';

void checkKeyParam(Object? key) {
  if (key == null) {
    throw DatabaseNoKeyError();
  }
  if (!(key is String || key is num)) {
    if (key is List && key.isNotEmpty) {
      final keyList = key;
      for (var item in keyList) {
        checkKeyParam(item);
      }
      return;
    }
    throw DatabaseInvalidKeyError(key);
  }
}

/// Check a key
/// keyPath can be: List<String> | String
void checkKeyValueParam(
    {Object? keyPath, Object? key, Object? value, bool? autoIncrement}) {
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
