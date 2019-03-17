import 'package:sembast/sembast.dart' as sdb;

dynamic escapeKeyPath(dynamic keyPath) {
  if (keyPath is String) {
    return sdb.FieldKey.escape(keyPath);
  } else if (keyPath is List) {
    return keyPath
        .map((item) => sdb.FieldKey.escape(item as String))
        .toList(growable: false);
  }
  throw 'invalid keyPath $keyPath';
}
