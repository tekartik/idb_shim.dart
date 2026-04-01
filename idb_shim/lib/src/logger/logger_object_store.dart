// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/logger/logger_database.dart';
import 'package:idb_shim/src/logger/logger_transaction.dart';

import 'logger_index.dart';
import 'logger_utils.dart';

class ObjectStoreLogger extends ObjectStore {
  /// Specified during open.
  final DatabaseLogger? idbDatabaseLogger;

  /// Specified in a transaction.
  final TransactionLogger? idbTransactionLogger;
  ObjectStore idbObjectStore;

  ObjectStoreLogger(
    this.idbDatabaseLogger,
    this.idbTransactionLogger,
    this.idbObjectStore,
  );
  String _storeMessage(String message) => "'${idbObjectStore.name}' $message";
  void log(String message) {
    if (idbTransactionLogger != null) {
      idbTransactionLogger?.log(_storeMessage(message));
    } else if (idbDatabaseLogger != null) {
      idbDatabaseLogger?.log(_storeMessage(message));
    }
  }

  void err(String message) {
    if (idbTransactionLogger != null) {
      idbTransactionLogger?.err(_storeMessage(message));
    } else if (idbDatabaseLogger != null) {
      idbDatabaseLogger?.err(_storeMessage(message));
    }
  }

  @override
  Index createIndex(String name, keyPath, {bool? unique, bool? multiEntry}) {
    var isUnique = unique ?? false;
    var isMultiEntry = multiEntry ?? false;
    log(
      'createIndex $name on ${this.name} keyPath $keyPath${(isUnique || isMultiEntry) ? ''
                '(${isUnique ? 'unique' : ''}'
                '${isMultiEntry ? (isUnique ? ', multi' : 'multi') : ''})' : ''}',
    );
    return idbObjectStore.createIndex(
      name,
      keyPath,
      unique: unique,
      multiEntry: multiEntry,
    );
  }

  @override
  void deleteIndex(String name) {
    log('deleteIndex($name');
    idbObjectStore.deleteIndex(name);
  }

  @override
  Future<Object> add(Object value, [Object? key]) async {
    try {
      var result = await idbObjectStore.add(value, key);
      log(
        'add(${_debugSafeValue(value)}${key != null ? ', $key' : ''}): $result',
      );
      return result;
    } catch (e) {
      err('add(${_debugSafeValue(value)}, $key) failed $e');
      rethrow;
    }
  }

  // Not async please for ie!
  @override
  Future<Object?> getObject(Object key) {
    return idbObjectStore
        .getObject(key)
        .then((value) {
          log('get(${_debugSafeKey(key)}: ${_debugSafeValue(value)}');
          return value;
        })
        .onError((err, st) {
          log('get(${_debugSafeKey(key)}) failed $err');
          return err;
        });
  }

  @override
  Future<void> clear() {
    return idbObjectStore.clear().then((_) {
      log('clear');
    });
  }

  String _debugSafeKey(Object? key) => logTruncateAny(key ?? '<null key>');

  String _debugSafeValue(Object? value) => logTruncateAny(value, len: 256);

  @override
  Future<Object> put(Object value, [Object? key]) async {
    try {
      var result = await idbObjectStore.put(value, key);
      log(
        'put(${_debugSafeValue(value)}${key != null ? ', ${_debugSafeKey(key)}' : ''}): ${_debugSafeValue(result)}',
      );
      return result;
    } catch (e) {
      err('put(${_debugSafeValue(value)}, ${_debugSafeKey(key)}) failed $e');
      rethrow;
    }
  }

  @override
  Future delete(Object keyOrRange) {
    return idbObjectStore.delete(keyOrRange);
  }

  @override
  Index index(String name) {
    return IndexLogger(this, idbObjectStore.index(name));
  }

  @override
  Stream<CursorWithValue> openCursor({
    key,
    KeyRange? range,
    String? direction,
    bool? autoAdvance,
  }) => idbObjectStore.openCursor(
    key: key,
    range: range,
    direction: direction, //
    autoAdvance: autoAdvance,
  );

  @override
  Stream<Cursor> openKeyCursor({
    key,
    KeyRange? range,
    String? direction,
    bool? autoAdvance,
  }) => idbObjectStore.openKeyCursor(
    key: key,
    range: range,
    direction: direction,
    autoAdvance: autoAdvance,
  );

  @override
  Future<int> count([dynamic keyOrRange]) => idbObjectStore.count(keyOrRange);

  @override
  Future<List<Object>> getAll([Object? query, int? count]) =>
      idbObjectStore.getAll(query, count);

  @override
  Future<List<Object>> getAllKeys([Object? query, int? count]) =>
      idbObjectStore.getAllKeys(query, count);

  @override
  dynamic get keyPath => idbObjectStore.keyPath;

  @override
  bool get autoIncrement => idbObjectStore.autoIncrement;

  @override
  String get name => idbObjectStore.name;

  @override
  List<String> get indexNames => idbObjectStore.indexNames;
}
