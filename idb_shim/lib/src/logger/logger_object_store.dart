import 'dart:async';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/logger/logger_transaction.dart';

import 'logger_index.dart';

class ObjectStoreLogger extends ObjectStore {
  final TransactionLogger idbTransactionLogger;
  ObjectStore idbObjectStore;

  ObjectStoreLogger(this.idbTransactionLogger, this.idbObjectStore);

  void log(String message) => idbTransactionLogger.log(message);

  void err(String message) => idbTransactionLogger.err(message);

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    return idbObjectStore.createIndex(name, keyPath,
        unique: unique, multiEntry: multiEntry);
  }

  @override
  void deleteIndex(String name) {
    log('deleteIndex($name');

    idbObjectStore.deleteIndex(name);
  }

  @override
  Future add(dynamic value, [dynamic key]) async {
    try {
      var result = await idbObjectStore.add(value, key);
      log('add($value${key != null ? ', $key' : ''}): $result');
      return result;
    } catch (e) {
      err('add($value, $key) failed $e');
      rethrow;
    }
  }

  // Not async please for ie!
  @override
  Future getObject(dynamic key) {
    return idbObjectStore.getObject(key);
  }

  @override
  Future clear() {
    return idbObjectStore.clear();
  }

  @override
  Future put(dynamic value, [dynamic key]) async {
    try {
      var result = await idbObjectStore.put(value, key);
      log('put($value${key != null ? ', $key' : ''}): $result');
      return result;
    } catch (e) {
      err('put($value, $key) failed $e');
      rethrow;
    }
  }

  @override
  Future delete(key) {
    return idbObjectStore.delete(key);
  }

  @override
  Index index(String name) {
    return IndexLogger(this, idbObjectStore.index(name));
  }

  @override
  Stream<CursorWithValue> openCursor(
          {key, KeyRange range, String direction, bool autoAdvance}) =>
      idbObjectStore.openCursor(
          key: key,
          range: range,
          direction: direction, //
          autoAdvance: autoAdvance);

  @override
  Stream<Cursor> openKeyCursor(
          {key, KeyRange range, String direction, bool autoAdvance}) =>
      idbObjectStore.openKeyCursor(
          key: key,
          range: range,
          direction: direction,
          autoAdvance: autoAdvance);

  @override
  Future<int> count([dynamic keyOrRange]) => idbObjectStore.count(keyOrRange);

  @override
  Future<List<dynamic>> getAll([dynamic keyOrRange, int count]) =>
      idbObjectStore.getAll(keyOrRange, count);

  @override
  Future<List<dynamic>> getAllKeys([dynamic keyOrRange, int count]) =>
      idbObjectStore.getAllKeys(keyOrRange, count);

  @override
  dynamic get keyPath => idbObjectStore.keyPath;

  @override
  bool get autoIncrement => idbObjectStore.autoIncrement;

  @override
  String get name => idbObjectStore.name;

  @override
  List<String> get indexNames => idbObjectStore.indexNames;
}
