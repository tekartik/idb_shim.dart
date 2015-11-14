@TestOn("browser")
library idb_shim.test_runner_client_native_test;

import 'idb_test_common.dart';
import 'test_runner.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client.dart';
import 'idb_browser_test_common.dart';
import 'dart:indexed_db' as idb;
import 'dart:html';

main() {
  group('native', () {
    if (IdbNativeFactory.supported) {
      IdbFactory idbFactory = new IdbNativeFactory();
      TestContext ctx = new TestContext()..factory = idbFactory;

      // ie and idb special test marker
      ctx.isIdbIe = isIe;
      ctx.isIdbSafari = isSafari;

      test('properties', () {
        expect(idbFactory.persistent, isTrue);
      });

      defineTests(ctx);
    } else {
      test("idb native not supported", null, skip: "idb native not supported");
    }
  });

  group('raw', () {
    // Safari crashes if there is a pause
    // after the transaction creation
    // true on dart version 1.12
    // not anymore on dart version 1.13
    test('pause_after_transaction', () async {
      String dbName = testDescriptions.join('_');
      await window.indexedDB.deleteDatabase(dbName);
      idb.Database db = await window.indexedDB.open(dbName, version: 1,
          onUpgradeNeeded: (idb.VersionChangeEvent e) {
        idb.Database db = (e.target as idb.Request).result;
        db.createObjectStore("store", autoIncrement: true);
      });

      idb.Transaction transaction;
      idb.ObjectStore objectStore;
      _createTransactionSync() {
        transaction = db.transaction("store", "readonly");
        objectStore = transaction.objectStore("store");
      }
      _createTransaction() async {
        await new Future.delayed(new Duration(milliseconds: 1));
        _createTransactionSync();
      }

      // Sync ok
      _createTransactionSync();
      await objectStore.getObject(0);
      await transaction.completed;

      // Async not ok on Safari
      await _createTransaction();
      try {
        await objectStore.getObject(0);
        if (isSafari) {
          fail('should fail');
        }
      } catch (e) {
        // Transaction inactive
        print(e);
        expect(e.message.contains("TransactionInactiveError"), isTrue);
      }
      return transaction.completed;
    }, skip: "fails on 1.13, no more transaction delay issues");

    // ie crashes if there is a pause between 2 calls
    // after the transaction creation
    test('pause_between_calls', () async {
      String dbName = testDescriptions.join('_');
      await window.indexedDB.deleteDatabase(dbName);
      idb.Database db = await window.indexedDB.open(dbName, version: 1,
          onUpgradeNeeded: (idb.VersionChangeEvent e) {
        idb.Database db = (e.target as idb.Request).result;
        db.createObjectStore("store", autoIncrement: true);
      });

      idb.Transaction transaction;
      idb.ObjectStore objectStore;
      _createTransactionSync() {
        transaction = db.transaction("store", "readonly");
        objectStore = transaction.objectStore("store");
      }

      // Sync ok
      _createTransactionSync();
      await objectStore.getObject(0);
      await new Future.value();

      try {
        await objectStore.getObject(0);
        if (isIe) {
          fail('should fail');
        }
      } catch (e) {
        // Transaction inactive
        expect(e.message.contains("TransactionInactiveError"), isTrue);
      }
      return transaction.completed;
    });
  });
}
