import 'package:idb_shim/idb_sdb.dart';
import 'package:idb_shim/src/sdb/sdb_utils.dart';
// ignore: implementation_imports
import 'package:sembast/src/api/protected/key_utils.dart' as key_utils;

/// Generate a string key. re-use the sembast one.
String generateStringKey() => key_utils.generateStringKey();

/// Convert an indexKey (that can be a record)
Object sdbIndexKeyToIdbKey(Object indexKey) {
  if (indexKey is (Object?, Object?, Object?, Object?)) {
    return [
      sdbToIndexKeyValue(indexKey.$1),
      sdbToIndexKeyValue(indexKey.$2),
      sdbToIndexKeyValue(indexKey.$3),
      sdbToIndexKeyValue(indexKey.$4),
    ];
  } else if (indexKey is (Object?, Object?, Object?)) {
    return [
      sdbToIndexKeyValue(indexKey.$1),
      sdbToIndexKeyValue(indexKey.$2),
      sdbToIndexKeyValue(indexKey.$3),
    ];
  } else if (indexKey is (Object?, Object?)) {
    return [sdbToIndexKeyValue(indexKey.$1), sdbToIndexKeyValue(indexKey.$2)];
  } else {
    return sdbToIndexKeyValue(indexKey);
  }
}

/// Check that K is a valid SdbKey type
void sdbCheckKeyType<K>() {
  // We tolerate Object as dynamic
  if (!(K == int || K == String || K == Object)) {
    throw ArgumentError('K type $K must be int or String');
  }
}

/// Check that K is a valid index SdbKey type
void sdbCheckIndexKeyType<K>() {
  // We tolerate Object as dynamic
  if (!(K == int || K == String || K == Object || K == SdbTimestamp)) {
    throw ArgumentError('K type $K must be int, String or SdbTimestamp');
  }
}
