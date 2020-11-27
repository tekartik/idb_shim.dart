import 'package:idb_shim/idb.dart';
import 'package:test/test.dart';

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
  });
}
