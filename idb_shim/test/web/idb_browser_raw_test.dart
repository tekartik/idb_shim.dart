// ignore_for_file: avoid_print

@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart';

void main() {
  test('idb_browser_raw_test', () async {
    var dbName = 'test_raw.db';

    // Delete the database
    await EventStreamProviders.successEvent
        .forTarget(window.indexedDB.deleteDatabase(dbName))
        .first;

    late Object createObjectStoreError;
    // Open the database and create an object store
    var openRequest = window.indexedDB.open(dbName, 1);
    EventStreamProviders.upgradeNeededEvent
        .forTarget(openRequest)
        .listen((IDBVersionChangeEvent event) {
      var db = openRequest.result as IDBDatabase;
      db.createObjectStore('test');

      // Add it again, an error should be thrown
      try {
        db.createObjectStore('test');
      } catch (e) {
        createObjectStoreError = e;
      }
    });
    await EventStreamProviders.successEvent.forTarget(openRequest).first;

    print(createObjectStoreError.runtimeType);
    print(createObjectStoreError);

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
