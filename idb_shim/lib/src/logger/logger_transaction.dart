import 'dart:async';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_transaction.dart';
import 'package:idb_shim/src/logger/logger_database.dart';
import 'package:idb_shim/src/logger/logger_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

class TransactionLogger extends IdbTransactionBase {
  Transaction idbTransaction;

  DatabaseLogger get idbDatabaseLogger => database as DatabaseLogger;

  TransactionLogger(DatabaseLogger database, this.idbTransaction)
      : super(database);

  @override
  ObjectStore objectStore(String name) =>
      ObjectStoreLogger(this, idbTransaction.objectStore(name));

  @override
  Future<Database> get completed {
    try {
      idbTransaction.completed.catchError((e) {
        idbDatabaseLogger.err('completed error $e');
      }).whenComplete(() {
        idbDatabaseLogger.log('completed');
      });
      return idbTransaction.completed;
    } catch (e) {
      idbDatabaseLogger.err('completed sync error $e');
      rethrow;
    }
  }

  @override
  void abort() {
    idbDatabaseLogger.log('abort');
    idbTransaction.abort();
  }

  void log(String message) {
    idbDatabaseLogger.log(message);
  }

  void err(String message) {
    idbDatabaseLogger.err(message);
  }
}
