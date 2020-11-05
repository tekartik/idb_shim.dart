import 'dart:async';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_shim/src/common/common_database.dart';
import 'package:idb_shim/src/logger/logger_transaction.dart';
import 'package:idb_shim/src/native/native_error.dart';

import 'logger_utils.dart';

class DatabaseLogger extends IdbDatabaseBase {
  final int id;
  Database idbDatabase;

  IdbFactoryLogger get logger => factory as IdbFactoryLogger;

  DatabaseLogger({IdbFactoryLogger factory, this.idbDatabase, this.id})
      : super(factory);

  @override
  int get version => idbDatabase.version;

  void log(String message) {
    logger.log(message, id: id);
  }

  void err(String message) {
    logger.err(message, id: id);
  }

  @override
  ObjectStore createObjectStore(String name,
      {String keyPath, bool autoIncrement}) {
    log('createObjectStore($name${getPropertyMapText({
      'keyPath': keyPath,
      'autoIncrement': autoIncrement
    })})');
    try {
      var store = idbDatabase.createObjectStore(name,
          keyPath: keyPath, autoIncrement: autoIncrement);
      return store;
    } catch (e) {
      err('createObjectStore($name) failed $e');
      rethrow;
    }
  }

  @override
  Transaction transaction(storeNameOrStoreNames, String mode) {
    log('transaction $mode on $storeNameOrStoreNames');
    return TransactionLogger(
        this, idbDatabase.transaction(storeNameOrStoreNames, mode));
  }

  @override
  Transaction transactionList(List<String> storeNames, String mode) =>
      transaction(storeNames, mode);

  @override
  void close() {
    return catchNativeError(() {
      idbDatabase.close();
    });
  }

  @override
  void deleteObjectStore(String name) {
    log('deleteObjectStore($name');
    idbDatabase.deleteObjectStore(name);
  }

  @override
  Iterable<String> get objectStoreNames => idbDatabase.objectStoreNames;

  @override
  String get name => idbDatabase.name;

  @override
  Stream<VersionChangeEvent> get onVersionChange => idbDatabase.onVersionChange;
}