// ignore: implementation_imports
import 'package:idb_shim/src/sdb/sdb_schema.dart';

/// Only for store keyPath conversion
SdbKeyPath? idbKeyPathToSdbKeyPathOrNull(Object? idbKeyPath) {
  if (idbKeyPath == null) {
    return null;
  }
  if (idbKeyPath is String && idbKeyPath.isEmpty) {
    return null;
  }
  if (idbKeyPath is List && idbKeyPath.isEmpty) {
    return null;
  }
  return idbKeyPathToSdbKeyPath(idbKeyPath);
}

/// Only handle String or List of String
Object sdbKeyPathToIdbKeyPath(SdbKeyPath sdbKeyPath) {
  if (sdbKeyPath.isSingle) {
    return sdbKeyPath.keyPaths.first;
  } else {
    return sdbKeyPath.keyPaths;
  }
}

/// Only handle String or List of String
SdbKeyPath idbKeyPathToSdbKeyPath(Object idbKeyPath) {
  if (idbKeyPath is String) {
    return SdbKeyPath.single(idbKeyPath);
  } else if (idbKeyPath is List) {
    assert(idbKeyPath.isNotEmpty);
    if (idbKeyPath.length == 1) {
      return SdbKeyPath.single(idbKeyPath[0].toString());
    } else {
      return SdbKeyPath.multi(idbKeyPath.map((e) => e!.toString()).toList());
    }
  } else {
    throw ArgumentError.value(
      idbKeyPath,
      'idbKeyPath',
      'Unsupported keyPath type',
    );
  }
}

/// Handle String, `List<String>` or SdbKeyPath
///
/// Returns String or `List<String>`
Object idbKeyPathFromAny(Object keyPath) {
  if (keyPath is String) {
    return keyPath;
  }
  return sdbKeyPathToIdbKeyPath(sdbKeyPathFromAny(keyPath));
}

/// Handle String, `List<String>` or SdbKeyPath
///
/// Returns SdbKeyPath
SdbKeyPath sdbKeyPathFromAny(Object keyPath) {
  if (keyPath is SdbKeyPath) {
    return keyPath;
  } else {
    return idbKeyPathToSdbKeyPath(keyPath);
  }
}
