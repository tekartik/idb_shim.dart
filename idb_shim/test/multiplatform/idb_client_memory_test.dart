import 'package:idb_shim/idb.dart';

import '../idb_test_common.dart';

void main() {
  group('inMemory', () {
    test('new', () async {
      var factory1 = newIdbFactoryMemory();
      var db1 =
          await factory1.open('test', version: 1, onUpgradeNeeded: (event) {
        final db = event.database;
        // create the store
        db.createObjectStore('test');
      });
      var txn = db1.transaction('test', idbModeReadWrite);
      var store = txn.objectStore('test');
      await store.put('test', 1);
      expect(await store.getObject(1), 'test');
      await txn.completed;
      db1.close();

      var factory2 = newIdbFactoryMemory();
      var db2 =
          await factory2.open('test', version: 1, onUpgradeNeeded: (event) {
        final db = event.database;
        // create the store
        db.createObjectStore('test');
      });
      txn = db2.transaction('test', idbModeReadWrite);
      store = txn.objectStore('test');
      expect(await store.getObject(1), isNull);
      await txn.completed;
      db1.close();
    });

    test('index key cursor delete', () async {
      var factory1 = newIdbFactoryMemory();
      var db1 =
          await factory1.open('test', version: 1, onUpgradeNeeded: (event) {
        final db = event.database;
        final objectStore =
            db.createObjectStore(testStoreName, autoIncrement: true);
        objectStore.createIndex(testNameIndex, testNameField);
      });
      var txn = db1.transaction(testStoreName, idbModeReadWrite);
      var store = txn.objectStore(testStoreName);
      await store.put({testNameField: 'value1'});
      var index = store.index(testNameIndex);
      Object? exception;
      await index.openKeyCursor(autoAdvance: true).listen((cursor) async {
        // devPrint('cursor: $cursor');
        try {
          await cursor.delete();
        } catch (e) {
          exception = e;
        }
      }).asFuture();

      await txn.completed;

      db1.close();
      expect(exception, isA<StateError>());
    });
  });
}
