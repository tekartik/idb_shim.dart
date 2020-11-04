import 'dart:async';
import 'dart:indexed_db' as idb;

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_transaction.dart';
import 'package:idb_shim/src/native/native_database.dart';
import 'package:idb_shim/src/native/native_error.dart';
import 'package:idb_shim/src/native/native_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

abstract class TransactionNativeBase extends IdbTransactionBase {
  TransactionNativeBase(Database database) : super(database);
}

class TransactionNative extends TransactionNativeBase {
  idb.Transaction idbTransaction;

  TransactionNative(Database database, this.idbTransaction) : super(database);
  final _completed = Completer<Database>.sync();

  void _complete() {
    if (!_completed.isCompleted) {
      _completed.complete(database);
    }
  }

  void _completeError(e) {
    if (!_completed.isCompleted) {
      _completed.completeError(e);
    }
  }

  @override
  ObjectStore objectStore(String name) {
    return catchNativeError(() {
      final idbObjectStore = idbTransaction.objectStore(name);
      return ObjectStoreNative(idbObjectStore);
    });
  }

  @override
  Future<Database> get completed async {
    // ignore: unawaited_futures
    () async {
      try {
        await idbTransaction.completed;
        _complete();
      } catch (e) {
        _completeError(e);
      }
    }();
    return _completed.future;
  }

  @override
  void abort() {
    return catchNativeError(() {
      idbTransaction.abort();
    });
  }
}

//
// Safari fake multistore transaction
// create the transaction when objectStore is called
class FakeMultiStoreTransactionNative extends TransactionNativeBase {
  //List<_NativeTransaction> transactions = [];
  // We sequencialize the transactions
  DatabaseNative get _nativeDatabase => (database as DatabaseNative);
  TransactionNative lastTransaction;
  ObjectStore lastStore;

  idb.Database get idbDatabase => _nativeDatabase.idbDatabase;
  String mode;

  FakeMultiStoreTransactionNative(Database database, this.mode)
      : super(database);

  @override
  ObjectStore objectStore(String name) {
    if (lastTransaction != null) {
      // same store, reuse it
      if (lastStore.name == name) {
        return lastStore;
      }

      // will wait for the previous transaction to be completed
      // so that it wannot be re-used
      lastTransaction.completed;
    }
    lastTransaction =
        _nativeDatabase.transaction(name, mode) as TransactionNative;
    lastStore = lastTransaction.objectStore(name);
    return lastStore;
  }

  @override
  Future<Database> get completed {
    if (lastTransaction == null) {
      return Future.value(database);
    } else {
      // Somehow waiting for all transaction hangs
      // just wait for the last one created!
      return lastTransaction.completed;
    }
  }

  @override
  void abort() {
    // Not supported
    print('abort not supported in fake multistore transaction');
  }
}
