// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:html_common' as html_common;
import 'dart:indexed_db' as idb;

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_database.dart';
import 'package:idb_shim/src/native/native_error.dart';
import 'package:idb_shim/src/native/native_object_store.dart';
import 'package:idb_shim/src/native/native_transaction.dart';
import 'package:idb_shim/src/utils/browser_utils.dart';

class VersionChangeEventNative extends IdbVersionChangeEventBase {
  final IdbFactory factory;
  idb.VersionChangeEvent idbVersionChangeEvent;

  @override
  int get oldVersion => idbVersionChangeEvent.oldVersion!;

  @override
  int get newVersion => idbVersionChangeEvent.newVersion!;
  late Request request;

  @override
  Object get target => request;

  @override
  Transaction get transaction => request.transaction;

  @override
  late Database database;

  VersionChangeEventNative(this.factory, this.idbVersionChangeEvent) {
    // This is null for onChangeEvent on Database
    // but ok when opening the database
    dynamic currentTarget = idbVersionChangeEvent.currentTarget;
    if (currentTarget is idb.Database) {
      database = DatabaseNative(factory, currentTarget);
    } else if (currentTarget is idb.Request) {
      database = DatabaseNative(factory, currentTarget.result as idb.Database?);
      final transaction =
          TransactionNative(database, currentTarget.transaction!);
      request = OpenDBRequest(database, transaction);
    }
  }
}

class DatabaseNative extends IdbDatabaseBase {
  idb.Database? idbDatabase;

  DatabaseNative(super.factory, this.idbDatabase);

  @override
  int get version => catchNativeError((() => idbDatabase!.version ?? 0));

  @override
  ObjectStore createObjectStore(String name,
      {Object? keyPath, bool? autoIncrement}) {
    return catchNativeError(() {
      return ObjectStoreNative(idbDatabase!.createObjectStore(name,
          keyPath: keyPath, autoIncrement: autoIncrement));
    })!;
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
        final idbTransaction =
            idbDatabase!.transaction(storeNameOrStoreNames, mode);
        return TransactionNative(this, idbTransaction);
      })!;
    } catch (e) {
      // Only handle the issue for non empty list returning a NotFoundError
      if ((storeNameOrStoreNames is List) &&
          (storeNameOrStoreNames.isNotEmpty) &&
          (_isNotFoundError(e))) {
        final stores = storeNameOrStoreNames.cast<String>();

        // Make sure they indeed exists
        var allFound = true;
        for (final store in stores) {
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
                final idbTransaction = idbDatabase!.transaction(
                    html_common.convertDartToNative_SerializedScriptValue(
                        storeNameOrStoreNames),
                    mode);
                return TransactionNative(this, idbTransaction);
              })!;
            } catch (_) {}
          }
        }
      }
      rethrow;
    }
  }

  bool _isNotFoundError(Object e) {
    if (e is DatabaseError) {
      final message = e.toString().toLowerCase();
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
      idbDatabase!.close();
    });
  }

  @override
  void deleteObjectStore(String name) {
    return catchNativeError(() {
      idbDatabase!.deleteObjectStore(name);
    });
  }

  @override
  Iterable<String> get objectStoreNames {
    return catchNativeError(() {
      return idbDatabase!.objectStoreNames ?? <String>[];
    })!;
  }

  @override
  String get name => catchNativeError(() => idbDatabase!.name!)!;

  @override
  Stream<VersionChangeEvent> get onVersionChange {
    final ctlr = StreamController<VersionChangeEvent>();
    idbDatabase!.onVersionChange.listen(
        (idb.VersionChangeEvent idbVersionChangeEvent) {
      ctlr.add(VersionChangeEventNative(factory, idbVersionChangeEvent));
    }, onDone: () {
      ctlr.close();
    }, onError: (Object error) {
      ctlr.addError(error);
    });
    return ctlr.stream;
  }
}
