import 'dart:indexed_db' as idb;

import 'package:idb_shim/idb.dart';

idb.KeyRange toNativeKeyRange(KeyRange common) {
  //print(common);
  if (common == null) {
    return null;
  }
  if (common.lower != null) {
    if (common.upper != null) {
      return idb.KeyRange.bound(common.lower, common.upper,
          common.lowerOpen == true, common.upperOpen == true);
    } else {
      return idb.KeyRange.lowerBound(common.lower, common.lowerOpen == true);
    }
  } else {
    return idb.KeyRange.upperBound(common.upper, common.upperOpen == true);
  }
}
