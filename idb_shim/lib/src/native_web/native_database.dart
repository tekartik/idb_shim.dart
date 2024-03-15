// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_database.dart';
import 'package:idb_shim/src/utils/env_utils.dart';

import 'indexed_db_web.dart' as idb;
import 'js_utils.dart';
import 'native_error.dart';
import 'native_object_store.dart';
import 'native_transaction.dart';

class VersionChangeEventNative extends IdbVersionChangeEventBase {
  final IdbFactory factory;
  final idb.IDBVersionChangeEvent idbVersionChangeEvent;
  idb.IDBOpenDBRequest get _idbRequest =>
      idbVersionChangeEvent.target as idb.IDBOpenDBRequest;

  @override
  int get oldVersion => idbVersionChangeEvent.oldVersion;

  @override
  int get newVersion => idbVersionChangeEvent.newVersion!;
  late Request request = OpenDBRequest(database, transaction);

  @override
  Object get target => request;

  @override
  late Transaction transaction =
      TransactionNative(database, _idbRequest.transaction!);

  @override
  late Database database =
      DatabaseNative(factory, _idbRequest.result as idb.IDBDatabase);

  VersionChangeEventNative(this.factory, this.idbVersionChangeEvent);
}

class DatabaseNative extends IdbDatabaseBase {
  idb.IDBDatabase idbDatabase;
  StreamController<VersionChangeEvent>? onVersionChangeController;
  Stream<VersionChangeEvent>? onVersionChangeStream;
  DatabaseNative(super.factory, this.idbDatabase);

  @override
  int get version => catchNativeError((() => idbDatabase.version));

  @override
  ObjectStore createObjectStore(String name,
      {Object? keyPath, bool? autoIncrement}) {
    return catchNativeError(() {
      return ObjectStoreNative(idbDatabase.createObjectStore(
          name,
          idb.IDBObjectStoreParameters(
              keyPath: keyPath?.jsifyValue(),
              autoIncrement: autoIncrement ?? false)));
    })!;
  }

  @override
  TransactionNativeBase transaction(Object storeNameOrStoreNames, String mode) {
    // bug in 1.13
    // It only happens in dart for list
    // https://github.com/dart-lang/sdk/issues/25013

    // Safari has the issue of not supporting multistore
    // simulate them!
    try {
      return catchNativeError(() {
        final idbTransaction =
            idbDatabase.transaction(storeNameOrStoreNames.jsifyValue(), mode);
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
          if (kIdbDartIsWeb) {
            // In javascript this is likely a safari issue...
            return FakeMultiStoreTransactionNative(this, mode);
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
    /// Close pending streams.
    onVersionChangeController?.close();

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
      return idbDatabase.objectStoreNames.toStringIterable();
    })!;
  }

  @override
  String get name => catchNativeError(() => idbDatabase.name)!;

  @override
  Stream<VersionChangeEvent> get onVersionChange {
    if (onVersionChangeController == null) {
      onVersionChangeController = StreamController<VersionChangeEvent>();
      idbDatabase.onversionchange =
          (idb.IDBVersionChangeEvent idbVersionChangeEvent) {
        onVersionChangeController!
            .add(VersionChangeEventNative(factory, idbVersionChangeEvent));
      }.toJS;
      onVersionChangeStream =
          onVersionChangeController!.stream.asBroadcastStream();
    }

    return onVersionChangeStream!;
  }

  @override
  String toString() => 'DatabaseNative($name)';
}
