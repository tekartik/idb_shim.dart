@TestOn('browser')
library idb_shim.test_runner_client_native_test;

import 'dart:html';
import 'dart:indexed_db' as idb;
import 'dart:indexed_db';
import 'dart:typed_data';

import 'package:idb_shim/idb.dart' show idbModeReadWrite;

import '../idb_test_common.dart';
import 'idb_browser_test_common.dart';

void main() {
  group('raw', () {
    test('simple_readwrite_transaction', () async {
      final dbName = 'simple_readwrite_transaction.db';
      await window.indexedDB!.deleteDatabase(dbName);
      final db = await window.indexedDB!.open(dbName, version: 1,
          onUpgradeNeeded: (e) {
        // print(e);
        final db = e.target.result as idb.Database;
        db.createObjectStore('store', autoIncrement: true);
      });

      var transaction = db.transaction('store', 'readwrite');
      var objectStore = transaction.objectStore('store');
      var key = await objectStore.add('value');
      var value = await objectStore.getObject(key);
      expect(value, 'value');
      await transaction.completed;
    });

    test('simple_readonly_transaction', () async {
      final dbName = 'simple_readonly_transaction.db';
      await window.indexedDB!.deleteDatabase(dbName);
      final db = await window.indexedDB!.open(dbName, version: 1,
          onUpgradeNeeded: (e) {
        // print(e);
        final db = e.target.result as idb.Database;
        db.createObjectStore('store', autoIncrement: true);
      });

      var transaction = db.transaction('store', 'readwrite');
      var objectStore = transaction.objectStore('store');
      var key = await objectStore.add('value');
      var value = await objectStore.getObject(key);
      expect(value, 'value');
      await transaction.completed;
    });

    test('transaction_multi_store', () async {
      final dbName = 'transaction_multi_store';

      // This test now fails on dart 1.13
      await window.indexedDB!.deleteDatabase(dbName);
      final db = await window.indexedDB!.open(dbName, version: 1,
          onUpgradeNeeded: (e) {
        final db = e.target.result as idb.Database;
        db.createObjectStore('store1', autoIncrement: true);
        db.createObjectStore('store2', autoIncrement: true);
      });

      // This work
      var transaction = db.transaction(['store1'], 'readonly');
      await transaction.completed;

      // This works too
      transaction = db.transactionList(['store2'], 'readonly');
      await transaction.completed;

      // This fails now
      transaction = db.transactionList(['store1', 'store2'], 'readonly');
      await transaction.completed;
    }, skip: 'failing on 1.13');

    // Safari crashes if there is a pause
    // after the transaction creation
    // true on dart version 1.12
    // not anymore on dart version 1.13
    test('pause_after_transaction', () async {
      final dbName = 'pause_after_transaction.db';
      await window.indexedDB!.deleteDatabase(dbName);
      final db = await window.indexedDB!.open(dbName, version: 1,
          onUpgradeNeeded: (e) {
        final db = e.target.result as idb.Database;
        db.createObjectStore('store', autoIncrement: true);
      });

      idb.Transaction transaction;
      idb.ObjectStore objectStore;
      void createTransactionSync() {
        transaction = db.transaction('store', 'readonly');
        objectStore = transaction.objectStore('store');
      }

      Future createTransaction() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        createTransactionSync();
      }

      // Sync ok
      createTransactionSync();
      transaction = db.transaction('store', 'readonly');
      objectStore = transaction.objectStore('store');
      await objectStore.getObject(0);
      await transaction.completed;

      // Async ok even on Safari with dart 1.13
      await createTransaction();
      await objectStore.getObject(0);

      await transaction.completed;
    });

    // ie has issue with timing
    test('async_timing', () async {
      final dbName = 'async_timing';
      await window.indexedDB!.deleteDatabase(dbName);
      final db = await window.indexedDB!.open(dbName, version: 1,
          onUpgradeNeeded: (e) {
        final db = e.target.result as idb.Database;
        db.createObjectStore('store', autoIncrement: true);
      });

      late idb.Transaction transaction;
      late idb.ObjectStore objectStore;
      void createTransactionSync() {
        transaction = db.transaction('store', 'readonly');
        objectStore = transaction.objectStore('store');
      }

      createTransactionSync();
      await objectStore.getObject(0);
      Future get() async {
        await objectStore.getObject(0);
      }

      await get();

      await transaction.completed;
    }, skip: 'crashing on ie');

    test('future_timing', () async {
      final dbName = 'future_timing.db';
      await window.indexedDB!.deleteDatabase(dbName);
      final db = await window.indexedDB!.open(dbName, version: 1,
          onUpgradeNeeded: (e) {
        final db = e.target.result as idb.Database;
        db.createObjectStore('store', autoIncrement: true);
      });

      late idb.Transaction transaction;
      late idb.ObjectStore objectStore;
      void createTransactionSync() {
        transaction = db.transaction('store', 'readonly');
        objectStore = transaction.objectStore('store');
      }

      createTransactionSync();
      Future doGet() async {
        await objectStore.getObject(0);
      }

      await objectStore.getObject(0).then((_) async {
        await doGet();
      });

      await transaction.completed;
    }, skip: 'crashing on ie');

    // ie crashes if there is a pause between 2 calls
    // after the transaction creation
    test('pause_between_calls', () async {
      final dbName = 'pause_between_calls.db';
      await window.indexedDB!.deleteDatabase(dbName);
      final db = await window.indexedDB!.open(dbName, version: 1,
          onUpgradeNeeded: (e) {
        final db = e.target.result as idb.Database;
        db.createObjectStore('store', autoIncrement: true);
      });

      late idb.Transaction transaction;
      late idb.ObjectStore objectStore;
      void createTransactionSync() {
        transaction = db.transaction('store', 'readonly');
        objectStore = transaction.objectStore('store');
      }

      // Sync ok
      createTransactionSync();
      await objectStore.getObject(0);
      await Future<void>.value();

      try {
        await objectStore.getObject(0);
        if (isIe) {
          fail('should fail');
        }
      } catch (e) {
        // Transaction inactive
        expect(e.toString().contains('TransactionInactiveError'), isTrue);
      }
      return transaction.completed;
    });
    test('date_time', () async {
      final dbName = 'native_raw/date_time.db';
      await window.indexedDB!.deleteDatabase(dbName);
      final db = await window.indexedDB!.open(dbName, version: 1,
          onUpgradeNeeded: (e) {
        final db = e.target.result as idb.Database;
        db.createObjectStore('store', autoIncrement: true);
      });

      late idb.Transaction transaction;
      late idb.ObjectStore objectStore;
      void createTransactionSync() {
        transaction = db.transaction('store', idbModeReadWrite);
        objectStore = transaction.objectStore('store');
      }

      createTransactionSync();
      var key = await objectStore.add(DateTime.fromMillisecondsSinceEpoch(1));
      var keyBlob = await objectStore.add(Uint8List.fromList([1, 2, 3]));
      expect(
          (await objectStore.getObject(key) as DateTime).millisecondsSinceEpoch,
          1);
      expect((await objectStore.getObject(keyBlob) as Uint8List).length, 3);
      expect(
          await objectStore.getObject(keyBlob), const TypeMatcher<Uint8List>());
      return transaction.completed;
    });

    void expectThrow(KeyRange Function() action) {
      try {
        var result = action();
        fail('$result should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }
    }

    test('KeyRangeLowerBound', () {
      expectThrow(() => KeyRange.lowerBound(null, false));
      expectThrow(() => KeyRange.lowerBound(null, true));
      expectThrow(() => KeyRange.lowerBound([1, null], false));
      expectThrow(() => KeyRange.lowerBound([1, null], true));
      KeyRange.lowerBound([1, 1], false);
      KeyRange.lowerBound([1, 1], true);
    });
    test('KeyRangeUpperBound', () {
      expectThrow(() => KeyRange.upperBound(null, false));
      expectThrow(() => KeyRange.upperBound(null, true));
      expectThrow(() => KeyRange.upperBound([1, null], false));
      expectThrow(() => KeyRange.upperBound([1, null], true));
      KeyRange.upperBound([1, 1], false);
      KeyRange.upperBound([1, 1], true);
    });
    test('KeyRangeBound', () {
      expectThrow(() => KeyRange.bound(1, null, true, true));
      expectThrow(() => KeyRange.bound(null, 1, true, true));
      expectThrow(() => KeyRange.bound([1, null], [1, null], true, true));
      KeyRange.bound(1, 2, false, false);
      KeyRange.bound(1, 2, true, true);
    });
    test('key range', () {
      try {
        idb.KeyRange.lowerBound(null);
        fail('should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }
      try {
        idb.KeyRange.lowerBound(null, true);
        fail('should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }
      try {
        idb.KeyRange.lowerBound([1, null]);
        fail('should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }
      try {
        idb.KeyRange.lowerBound([1, null], true);
        fail('should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }

      try {
        idb.KeyRange.upperBound(null);
        fail('should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }
      try {
        idb.KeyRange.upperBound(null, true);
        fail('should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }
    });
  });
}
