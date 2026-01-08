// ignore_for_file: avoid_print

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:web/web.dart';

import 'idb_browser_raw_open_test.dart';

void main() {
  var dbName = 'test_raw_types.db';
  late IDBDatabase db;
  setUp(() async {
    try {
      // Delete the database
      await waitForSuccess(window.indexedDB.deleteDatabase(dbName));
    } catch (_) {}

    // Open the database and create an object store
    var openRequest = window.indexedDB.open(dbName, 1);
    EventStreamProviders.upgradeNeededEvent.forTarget(openRequest).listen((
      IDBVersionChangeEvent event,
    ) {
      var db = openRequest.result as IDBDatabase;
      db.createObjectStore('test');
    });
    await waitForSuccess(openRequest);
    db = openRequest.result as IDBDatabase;
  });
  tearDown(() async {
    db.close();
  });
  test('version', () {
    expect(db.version, 1);
  });

  test('idb_browser_raw_types_test', () async {
    var transaction = db.transaction('test'.toJS, 'readwrite');
    var store = transaction.objectStore('test');
    await waitForSuccess(store.put(0.toJS, 'int0'.toJS));

    final initialInt1 = 1.toJS;
    final intialDouble1 = 1.0.toJS;

    store.put(initialInt1, 'int1'.toJS);
    store.put(intialDouble1, 'double1'.toJS);
    print('put done');
    await waitForTransactionComplete(transaction);
    print('transaction complete');

    transaction = db.transaction('test'.toJS, 'readonly');
    store = transaction.objectStore('test');

    var int1 = await waitForSuccess(store.get('int1'.toJS));
    var dartInt1 = int1.dartify();
    print('int1: $int1 - runtimeType: ${int1.runtimeType}');
    print('dartInt1: $dartInt1 - runtimeType: ${dartInt1.runtimeType}');
    var double1 = await waitForSuccess(store.get('double1'.toJS));
    var dartDouble1 = double1.dartify();
    print('double1: $double1 - runtimeType: ${double1.runtimeType}');
    print(
      'dartDouble1: $dartDouble1 - runtimeType: ${dartDouble1.runtimeType}',
    );
    expect(int1, initialInt1);
    expect(dartInt1, 1);
    expect(dartInt1, isA<double>());
    expect(double1, 1.0.toJS);
    expect(dartDouble1, 1.0);
    expect(dartDouble1, isA<double>());
    await waitForTransactionComplete(transaction);
    //expect(value, isA<int>());
  });
}
