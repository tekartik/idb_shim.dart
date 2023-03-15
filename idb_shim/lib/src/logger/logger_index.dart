// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/logger/logger_object_store.dart';

class IndexLogger extends Index {
  Index idbIndex;

  final ObjectStoreLogger idbObjectStoreLogger;

  IndexLogger(this.idbObjectStoreLogger, this.idbIndex);

  @override
  Future get(Object key) => idbIndex.get(key);

  @override
  Future getKey(Object key) => idbIndex.getKey(key);

  @override
  Future<int> count([Object? keyOrRange]) => idbIndex.count(keyOrRange);

  @override
  Stream<Cursor> openKeyCursor(
          {key, KeyRange? range, String? direction, bool? autoAdvance}) =>
      idbIndex.openKeyCursor(
          key: key,
          range: range,
          direction: direction,
          autoAdvance: autoAdvance);

  /// Same implementation than for the Store
  @override
  Stream<CursorWithValue> openCursor(
          {key, KeyRange? range, String? direction, bool? autoAdvance}) =>
      idbIndex.openCursor(
          key: key,
          range: range,
          direction: direction,
          autoAdvance: autoAdvance);

  @override
  Future<List<Object>> getAll([Object? query, int? count]) =>
      idbIndex.getAll(query, count);

  @override
  Future<List<Object>> getAllKeys([Object? query, int? count]) =>
      idbIndex.getAllKeys(query, count);

  @override
  Object get keyPath => idbIndex.keyPath;

  @override
  bool get unique => idbIndex.unique;

  @override
  bool get multiEntry => idbIndex.multiEntry;

  @override
  int get hashCode => idbIndex.hashCode;

  @override
  String get name => idbIndex.name;

  @override
  bool operator ==(other) {
    if (other is IndexLogger) {
      return idbIndex == other.idbIndex;
    }
    return false;
  }
}
