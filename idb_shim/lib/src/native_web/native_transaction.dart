// ignore_for_file: public_member_api_docs

import 'dart:js_interop';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_transaction.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:idb_shim/src/utils/env_utils.dart';

import 'indexed_db_web.dart' as idb;
import 'native_database.dart';
import 'native_error.dart';
import 'native_object_store.dart';

abstract class TransactionNativeBase extends IdbTransactionBase {
  TransactionNativeBase(super.database);
}

class TransactionNative extends TransactionNativeBase {
  idb.IDBTransaction idbTransaction;

  TransactionNative(super.database, this.idbTransaction);

  late final Completer _completer = () {
    var completer = Completer<JSAny?>.sync();
    idbTransaction.onerror = (idb.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
            DatabaseErrorNative.domException(idbTransaction.error!));
      }
    }.toJS;
    idbTransaction.onabort = (idb.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
            DatabaseErrorNative('abort', 'Transaction was aborted'));
      }
    }.toJS;
    idbTransaction.oncomplete = (idb.Event event) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }.toJS;
    return completer;
  }();

  @override
  ObjectStore objectStore(String name) {
    return catchNativeError(() {
      final idbObjectStore = idbTransaction.objectStore(name);
      return ObjectStoreNative(idbObjectStore);
    })!;
  }

  @override
  Future<Database> get completed async {
    return _completer.future.then((_) => database);
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
  TransactionNative? lastTransaction;
  late ObjectStore lastStore;

  idb.IDBDatabase get idbDatabase => _nativeDatabase.idbDatabase;
  String mode;

  FakeMultiStoreTransactionNative(super.database, this.mode);

  @override
  ObjectStore objectStore(String name) {
    if (lastTransaction != null) {
      // same store, reuse it
      if (lastStore.name == name) {
        return lastStore;
      }

      // will wait for the previous transaction to be completed
      // so that it wannot be re-used
      lastTransaction!.completed;
    }
    lastTransaction =
        _nativeDatabase.transaction(name, mode) as TransactionNative;
    lastStore = lastTransaction!.objectStore(name);
    return lastStore;
  }

  @override
  Future<Database> get completed {
    if (lastTransaction == null) {
      return Future.value(database);
    } else {
      // Somehow waiting for all transaction hangs
      // just wait for the last one created!
      return lastTransaction!.completed;
    }
  }

  @override
  void abort() {
    // Not supported
    if (isDebug) {
      idbLog('abort not supported in fake multistore transaction');
    }
  }
}
