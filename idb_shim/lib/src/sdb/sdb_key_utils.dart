// ignore: implementation_imports
import 'package:sembast/src/api/protected/key_utils.dart' as key_utils;

/// Generate a string key. re-use the sembast one.
String generateStringKey() => key_utils.generateStringKey();

/// Convert an indexKey (that can be a record)
Object indexKeyToIdbKey(Object indexKey) {
  if (indexKey is (Object?, Object?, Object?, Object?)) {
    return [indexKey.$1, indexKey.$2, indexKey.$3, indexKey.$4];
  } else if (indexKey is (Object?, Object?, Object?)) {
    return [indexKey.$1, indexKey.$2, indexKey.$3];
  } else if (indexKey is (Object?, Object?)) {
    return [indexKey.$1, indexKey.$2];
  } else {
    return indexKey;
  }
}

/// Convert an idbKey (list) to an indexKey (record)
I idbKeyToIndexKey<I>(Object idbKey) {
  if (idbKey is List) {
    if (idbKey.length == 4) {
      return (idbKey[0], idbKey[1], idbKey[2], idbKey[3]) as I;
    } else if (idbKey.length == 3) {
      return (idbKey[0], idbKey[1], idbKey[2]) as I;
    } else if (idbKey.length == 2) {
      return (idbKey[0], idbKey[1]) as I;
    } else {
      throw StateError('keys with ${idbKey.length} fields keys are supported');
    }
  } else {
    return idbKey as I;
  }
}
