// ignore_for_file: public_member_api_docs

import 'dart:js_interop';

import 'package:idb_shim/idb.dart';

import 'indexed_db_web.dart' as idb;

idb.IDBKeyRange? toNativeKeyRange(KeyRange? common) {
  //print(common);
  if (common == null) {
    return null;
  }
  if (common.lower != null) {
    if (common.upper != null) {
      return idb.IDBKeyRange.bound(common.lower.jsify(), common.upper.jsify(),
          common.lowerOpen == true, common.upperOpen == true);
    } else {
      return idb.IDBKeyRange.lowerBound(
          common.lower.jsify(), common.lowerOpen == true);
    }
  } else {
    // devPrint('upper ${common.upper} ${common.upperOpen}');
    return idb.IDBKeyRange.upperBound(
        common.upper.jsify(), common.upperOpen == true);
  }
}

/// Convert a query (key range or key to a native object)
JSAny? toNativeQuery(Object? query) {
  if (query is KeyRange) {
    return toNativeKeyRange(query);
  }
  return query?.jsify();
}

JSAny? keyOrKeyRangeToNativeQuery({Object? key, KeyRange? range}) {
  dynamic keyOrRange;
  if (key != null) {
    if (range != null) {
      throw ArgumentError('Cannot specify both key and range.');
    }
    keyOrRange = key;
  } else {
    keyOrRange = range;
  }
  return toNativeQuery(keyOrRange);
}
