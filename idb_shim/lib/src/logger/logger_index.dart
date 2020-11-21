import 'dart:async';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/logger/logger_object_store.dart';

class IndexLogger extends Index {
  Index idbIndex;

  final ObjectStoreLogger idbObjectStoreLogger;

  IndexLogger(this.idbObjectStoreLogger, this.idbIndex);

  @override
  Future get(dynamic key) => idbIndex.get(key);

  @override
  Future getKey(dynamic key) => idbIndex.getKey(key);

  @override
  Future<int> count([keyOrRange]) => idbIndex.count(keyOrRange);

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
  Future<List<dynamic>> getAll([dynamic keyOrRange, int? count]) =>
      idbIndex.getAll(keyOrRange, count);

  @override
  Future<List<dynamic>> getAllKeys([dynamic keyOrRange, int? count]) =>
      idbIndex.getAllKeys(keyOrRange, count);

  @override
  dynamic get keyPath => idbIndex.keyPath;

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
