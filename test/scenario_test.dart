library idb_shim.scenario_test;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';

// File created to reproduce bugs

// so that this can be run directly
void main() => defineTests(idbTestMemoryFactory);

void defineTests(IdbFactory idbFactory) {
  //debugQuickLogging(Level.ALL);
  group('bug_put_delete', () {
    Database db;
    setUp(() async {
      await idbFactory.deleteDatabase(DB_NAME);
      void _initializeDatabase(VersionChangeEvent e) {
        db = e.database;
        db.createObjectStore(STORE_NAME, autoIncrement: true);
      }
      db = await idbFactory.open(DB_NAME,
          version: 1, onUpgradeNeeded: _initializeDatabase);
    });

    tearDown(() {
      db.close();
    });

    test('put_delete', () async {
      Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
      ObjectStore objectStore = transaction.objectStore(STORE_NAME);
      var key = await objectStore.put({});
      await objectStore.delete(key);
      await transaction.completed;
    });

    test('get_delete', () async {
      Transaction transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
      ObjectStore objectStore = transaction.objectStore(STORE_NAME);
      var key = await objectStore
          .put({"name": "name", "delete": true, "dirty": false});
      await transaction.completed;

      transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
      objectStore = transaction.objectStore(STORE_NAME);
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
