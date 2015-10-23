library idb_shim.scenario_test;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';

// File created to reproduce bugs

// so that this can be run directly
main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;
  //debugQuickLogging(Level.ALL);
  group('bug_put_delete', () {
    Database db;
    setUp(() async {
      await idbFactory.deleteDatabase(testDbName);
      void _initializeDatabase(VersionChangeEvent e) {
        db = e.database;
        db.createObjectStore(testStoreName, autoIncrement: true);
      }
      db = await idbFactory.open(testDbName,
          version: 1, onUpgradeNeeded: _initializeDatabase);
    });

    tearDown(() {
      db.close();
    });

    test('put_delete', () async {
      Transaction transaction = db.transaction(testStoreName, idbModeReadWrite);
      ObjectStore objectStore = transaction.objectStore(testStoreName);
      var key = await objectStore.put({});
      await objectStore.delete(key);
      await transaction.completed;
    });

    test('get_delete', () async {
      Transaction transaction = db.transaction(testStoreName, idbModeReadWrite);
      ObjectStore objectStore = transaction.objectStore(testStoreName);
      var key = await objectStore
          .put({"name": "name", "delete": true, "dirty": false});
      await transaction.completed;

      transaction = db.transaction(testStoreName, idbModeReadWrite);
      objectStore = transaction.objectStore(testStoreName);
      _get() async {
        Map row = await objectStore.getObject(key);
        return row;
      }
      await _get();
      await new Future.value();
      await objectStore.delete(key);
      await transaction.completed;
    });
  });
}
