// ignore_for_file: public_member_api_docs

import 'dart:js_interop';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/utils/env_utils.dart';

import 'indexed_db_web.dart' as idb;
import 'js_utils.dart';

idb.IDBKeyRange? toNativeKeyRange(KeyRange? common) {
  //print(common);
  if (common == null) {
    return null;
  }
  if (common.lower != null) {
    if (common.upper != null) {
      return idb.IDBKeyRange.bound(common.lower?.jsifyKey(),
          common.upper?.jsifyKey(), common.lowerOpen, common.upperOpen);
    } else {
      return idb.IDBKeyRange.lowerBound(
          common.lower?.jsifyKey(), common.lowerOpen);
    }
  } else {
    // devPrint('upper ${common.upper} ${common.upperOpen}');
    return idb.IDBKeyRange.upperBound(
        common.upper?.jsifyKey(), common.upperOpen);
  }
}

/// Convert a query (key range or key to a native object)
JSAny? toNativeQuery(Object? query) {
  if (query is KeyRange) {
    return toNativeKeyRange(query);
  }
  return query?.jsifyValue();
}

JSAny? keyOrKeyRangeToNativeQuery({Object? key, KeyRange? range}) {
  if (key != null) {
    if (isDebug) {
      if (range != null) {
        throw ArgumentError('Cannot specify both key and range.');
      }
      if (key is KeyRange) {
        throw ArgumentError(
            'Invalid keyRange $key as key argument, use the range argument');
      }
    }
    return key.jsifyKey();
  } else {
    return toNativeKeyRange(range);
  }
}
