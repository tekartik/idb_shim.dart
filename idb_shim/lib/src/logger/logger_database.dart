// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_shim/src/common/common_database.dart';
import 'package:idb_shim/src/logger/logger_object_store.dart';
import 'package:idb_shim/src/logger/logger_transaction.dart';

import 'logger_utils.dart';

class DatabaseLogger extends IdbDatabaseBase {
  final int id;
  Database idbDatabase;

  IdbFactoryLogger get logger => factory as IdbFactoryLogger;

  DatabaseLogger(
      {required IdbFactoryLogger factory,
      required this.idbDatabase,
      required this.id})
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
      {Object? keyPath, bool? autoIncrement}) {
    log('createObjectStore($name${getPropertyMapText({
          'keyPath': keyPath,
          'autoIncrement': autoIncrement
        }, true)})');
    try {
      var store = idbDatabase.createObjectStore(name,
          keyPath: keyPath, autoIncrement: autoIncrement);
      return ObjectStoreLogger(this, null, store);
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
    log('closing database');
    try {
      idbDatabase.close();
    } catch (_) {}
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
