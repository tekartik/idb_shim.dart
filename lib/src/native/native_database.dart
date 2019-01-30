import 'dart:async';
import 'dart:html_common' as html_common;
import 'dart:indexed_db' as idb;

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/src/common/common_database.dart';
import 'package:idb_shim/src/native/native_error.dart';
import 'package:idb_shim/src/native/native_object_store.dart';
import 'package:idb_shim/src/native/native_transaction.dart';
import 'package:idb_shim/src/utils/browser_utils.dart';

class VersionChangeEventNative extends IdbVersionChangeEventBase {
  idb.VersionChangeEvent idbVersionChangeEvent;

  @override
  int get oldVersion => idbVersionChangeEvent.oldVersion;

  @override
  int get newVersion => idbVersionChangeEvent.newVersion;
  Request request;

  @override
  Object get target => request;

  @override
  Transaction get transaction => request.transaction;

  @override
  Database database;

  VersionChangeEventNative(this.idbVersionChangeEvent) {
    // This is null for onChangeEvent on Database
    // but ok when opening the database
    dynamic currentTarget = idbVersionChangeEvent.currentTarget;
    if (currentTarget is idb.Database) {
      database = DatabaseNative(currentTarget);
    } else if (currentTarget is idb.Request) {
      database = DatabaseNative(currentTarget.result as idb.Database);
      TransactionNative transaction =
          TransactionNative(database, currentTarget.transaction);
      request = OpenDBRequest(database, transaction);
    }
  }
}

class DatabaseNative extends IdbDatabaseBase {
  idb.Database idbDatabase;

  DatabaseNative(this.idbDatabase) : super(idbNativeFactory);

  @override
  int get version => catchNativeError(() => idbDatabase.version);

  @override
  ObjectStore createObjectStore(String name,
      {String keyPath, bool autoIncrement}) {
    return catchNativeError(() {
      return ObjectStoreNative(idbDatabase.createObjectStore(name,
          keyPath: keyPath, autoIncrement: autoIncrement));
    });
  }

  @override
  TransactionNativeBase transaction(storeNameOrStoreNames, String mode) {
    // bug in 1.13
    // It only happens in dart for list
    // https://github.com/dart-lang/sdk/issues/25013

    // Safari has the issue of not supporting multistore
    // simulate them!
    try {
      return catchNativeError(() {
        idb.Transaction idbTransaction =
            idbDatabase.transaction(storeNameOrStoreNames, mode);
        return TransactionNative(this, idbTransaction);
      });
    } catch (e) {
      // Only handle the issue for non empty list returning a NotFoundError
      if ((storeNameOrStoreNames is List) &&
          (storeNameOrStoreNames.isNotEmpty) &&
          (_isNotFoundError(e))) {
        List<String> stores = storeNameOrStoreNames?.cast<String>();

        // Make sure they indeed exists
        bool allFound = true;
        for (String store in stores) {
          if (!objectStoreNames.contains(store)) {
            allFound = false;
            break;
          }
        }

        if (allFound) {
          if (!isDartVm) {
            // In javascript this is likely a safari issue...
            return FakeMultiStoreTransactionNative(this, mode);
          } else {
            // This is likely the 1.13 bug
            try {
              return catchNativeError(() {
                idb.Transaction idbTransaction = idbDatabase.transaction(
                    html_common.convertDartToNative_SerializedScriptValue(
                        storeNameOrStoreNames),
                    mode);
                return TransactionNative(this, idbTransaction);
              });
            } catch (_) {}
          }
        }
      }
      rethrow;
    }
  }

  bool _isNotFoundError(e) {
    if (e is DatabaseError) {
      String message = e.toString().toLowerCase();
      if (message.contains('notfounderror')) {
        return true;
      }
    }
    return false;
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
    return catchNativeError(() {
      idbDatabase.deleteObjectStore(name);
    });
  }

  @override
  Iterable<String> get objectStoreNames {
    return catchNativeError(() {
      return idbDatabase.objectStoreNames;
    });
  }

  @override
  String get name => catchNativeError(() => idbDatabase.name);

  @override
  Stream<VersionChangeEvent> get onVersionChange {
    StreamController<VersionChangeEvent> ctlr = StreamController();
    idbDatabase.onVersionChange.listen(
        (idb.VersionChangeEvent idbVersionChangeEvent) {
      ctlr.add(VersionChangeEventNative(idbVersionChangeEvent));
    }, onDone: () {
      ctlr.close();
    }, onError: (error) {
      ctlr.addError(error);
    });
    return ctlr.stream;
  }
}
