// ignore_for_file: avoid_print

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:idb_shim/src/native_web/js_utils.dart';
import 'package:web/web.dart';

import '../idb_test_common.dart';

var _extraDebug = false;
// var _extraDebug = devWarning(true);

Future<JSAny?> waitForSuccess(IDBRequest request) async {
  await EventStreamProviders.successEvent.forTarget(request).first;
  return request.result;
}

Future<void> waitForTransactionComplete(IDBTransaction transaction) async {
  await EventStreamProviders.completeEvent.forTarget(transaction).first;
}

void main() {
  test('idb_browser_raw_test', () async {
    var dbName = 'test_raw.db';

    // Delete the database
    await EventStreamProviders.successEvent
        .forTarget(window.indexedDB.deleteDatabase(dbName))
        .first;

    late Object createObjectStoreError;
    late StackTrace createObjectStoreStackStrace;
    // Open the database and create an object store
    var openRequest = window.indexedDB.open(dbName, 1);
    EventStreamProviders.upgradeNeededEvent.forTarget(openRequest).listen((
      IDBVersionChangeEvent event,
    ) {
      var db = openRequest.result as IDBDatabase;
      db.createObjectStore('test');

      // Add it again, an error should be thrown
      try {
        db.createObjectStore('test');
      } catch (e, st) {
        createObjectStoreError = e;
        createObjectStoreStackStrace = st;
      }
    });
    await EventStreamProviders.successEvent.forTarget(openRequest).first;

    print(createObjectStoreError.runtimeType);
    print(createObjectStoreError);

    final error = createObjectStoreError;
    final stackTrace = createObjectStoreStackStrace;
    print('error: $error');
    print('stackTrace: $stackTrace');
    try {
      if (error is Error) {
        print('is Error');
        print('error: $error');
        print('error.runtimeType: ${error.runtimeType}');
        //print('error.stackTrace: ${error.stackTrace}');
      } else {
        try {
          var jsObject = error as JSObject;
          print('is JSObject');

          var keys = jsObject.keys();
          print('keys: $keys');
          var propertyNames = jsObject.getOwnPropertyNames();
          print('props: $propertyNames');
          for (var prop in propertyNames) {
            try {
              var value = jsObject.getProperty(prop.toJS);
              if (_extraDebug) {
                print('  $prop: $value (${value.runtimeType})');
              }
            } catch (e) {
              print('  $prop: error $e');
            }
          }

          print('error.runtimeType: ${error.runtimeType}');
        } catch (e) {
          print('any: $error (${error.runtimeType}) ($e)');
        }
      }
    } catch (e) {
      print('raw JSObject conversion failed: $e');
    }

    // In dart2JS it displays
    // JSObject
    // ConstraintError: Failed to execute 'createObjectStore' on 'IDBDatabase': An object store with the specified name already exists.

    // In dart2Wasm it displays
    // _JavaScriptError
    // JavaScriptError
    var db = openRequest.result as IDBDatabase;

    db.close();
  });
}
