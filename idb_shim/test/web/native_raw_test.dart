@TestOn("browser")
library idb_shim.test_runner_client_native_test;

import 'dart:html';
import 'dart:indexed_db' as idb;

import '../idb_test_common.dart';
import 'idb_browser_test_common.dart';

void main() {
  group('raw', () {
    test('simple_readwrite_transaction', () async {
      String dbName = testDescriptions.join('_');
      await window.indexedDB.deleteDatabase(dbName);
      idb.Database db =
          await window.indexedDB.open(dbName, version: 1, onUpgradeNeeded: (e) {
        // print(e);
        idb.Database db = e.target.result as idb.Database;
        db.createObjectStore("store", autoIncrement: true);
      });

      var transaction = db.transaction("store", "readwrite");
      var objectStore = transaction.objectStore("store");
      var key = await objectStore.add("value");
      var value = await objectStore.getObject(key);
      expect(value, "value");
      await transaction.completed;
    });

    test('simple_readonly_transaction', () async {
      String dbName = testDescriptions.join('_');
      await window.indexedDB.deleteDatabase(dbName);
      idb.Database db =
          await window.indexedDB.open(dbName, version: 1, onUpgradeNeeded: (e) {
        // print(e);
        idb.Database db = e.target.result as idb.Database;
        db.createObjectStore("store", autoIncrement: true);
      });

      var transaction = db.transaction("store", "readwrite");
      var objectStore = transaction.objectStore("store");
      var key = await objectStore.add("value");
      var value = await objectStore.getObject(key);
      expect(value, "value");
      await transaction.completed;
    });

    test('transaction_multi_store', () async {
      String dbName = testDescriptions.join('_');

      // This test now fails on dart 1.13
      await window.indexedDB.deleteDatabase(dbName);
      idb.Database db =
          await window.indexedDB.open(dbName, version: 1, onUpgradeNeeded: (e) {
        idb.Database db = e.target.result as idb.Database;
        db.createObjectStore("store1", autoIncrement: true);
        db.createObjectStore("store2", autoIncrement: true);
      });

      // This work
      idb.Transaction transaction = db.transaction(["store1"], "readonly");
      await transaction.completed;

      // This works too
      transaction = db.transactionList(["store2"], "readonly");
      await transaction.completed;

      // This fails now
      transaction = db.transactionList(["store1", "store2"], "readonly");
      await transaction.completed;
    }, skip: "failing on 1.13");

    // Safari crashes if there is a pause
    // after the transaction creation
    // true on dart version 1.12
    // not anymore on dart version 1.13
    test('pause_after_transaction', () async {
      String dbName = testDescriptions.join('_');
      await window.indexedDB.deleteDatabase(dbName);
      idb.Database db =
          await window.indexedDB.open(dbName, version: 1, onUpgradeNeeded: (e) {
        idb.Database db = e.target.result as idb.Database;
        db.createObjectStore("store", autoIncrement: true);
      });

      idb.Transaction transaction;
      idb.ObjectStore objectStore;
      void _createTransactionSync() {
        transaction = db.transaction("store", "readonly");
        objectStore = transaction.objectStore("store");
      }

      Future _createTransaction() async {
        await Future.delayed(Duration(milliseconds: 1));
        _createTransactionSync();
      }

      // Sync ok
      _createTransactionSync();
      transaction = db.transaction("store", "readonly");
      objectStore = transaction.objectStore("store");
      await objectStore.getObject(0);
      await transaction.completed;

      // Async ok even on Safari with dart 1.13
      await _createTransaction();
      await objectStore.getObject(0);

      await transaction.completed;
    });

    // ie has issue with timing
    test('async_timing', () async {
      String dbName = testDescriptions.join('_');
      await window.indexedDB.deleteDatabase(dbName);
      idb.Database db =
          await window.indexedDB.open(dbName, version: 1, onUpgradeNeeded: (e) {
        idb.Database db = e.target.result as idb.Database;
        db.createObjectStore("store", autoIncrement: true);
      });

      idb.Transaction transaction;
      idb.ObjectStore objectStore;
      void _createTransactionSync() {
        transaction = db.transaction("store", "readonly");
        objectStore = transaction.objectStore("store");
      }

      _createTransactionSync();
      await objectStore.getObject(0);
      Future _get() async {
        await objectStore.getObject(0);
      }

      await _get();

      await transaction.completed;
    }, skip: 'crashing on ie');

    test('future_timing', () async {
      String dbName = testDescriptions.join('_');
      await window.indexedDB.deleteDatabase(dbName);
      idb.Database db =
          await window.indexedDB.open(dbName, version: 1, onUpgradeNeeded: (e) {
        idb.Database db = e.target.result as idb.Database;
        db.createObjectStore("store", autoIncrement: true);
      });

      idb.Transaction transaction;
      idb.ObjectStore objectStore;
      void _createTransactionSync() {
        transaction = db.transaction("store", "readonly");
        objectStore = transaction.objectStore("store");
      }

      _createTransactionSync();
      Future _get() async {
        await objectStore.getObject(0);
      }

      await objectStore.getObject(0).then((_) async {
        await _get();
      });

      await transaction.completed;
    }, skip: 'crashing on ie');

    // ie crashes if there is a pause between 2 calls
    // after the transaction creation
    test('pause_between_calls', () async {
      String dbName = testDescriptions.join('_');
      await window.indexedDB.deleteDatabase(dbName);
      idb.Database db =
          await window.indexedDB.open(dbName, version: 1, onUpgradeNeeded: (e) {
        idb.Database db = e.target.result as idb.Database;
        db.createObjectStore("store", autoIncrement: true);
      });

      idb.Transaction transaction;
      idb.ObjectStore objectStore;
      void _createTransactionSync() {
        transaction = db.transaction("store", "readonly");
        objectStore = transaction.objectStore("store");
      }

      // Sync ok
      _createTransactionSync();
      await objectStore.getObject(0);
      await Future.value();

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
