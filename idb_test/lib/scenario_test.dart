library idb_shim.scenario_test;

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';

// File created to reproduce bugs

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;
  //debugQuickLogging(Level.ALL);
  group('scenario', () {
    group('bug_put_delete', () {
      late Database db;
      Future dbSetUp() async {
        var dbName = ctx.dbName;
        await idbFactory.deleteDatabase(dbName);
        void onUpgradeNeeded(VersionChangeEvent e) {
          var database = e.database;
          database.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory.open(dbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(() {
        db.close();
      });

      test('put_delete', () async {
        await dbSetUp();
        final transaction = db.transaction(testStoreName, idbModeReadWrite);
        final objectStore = transaction.objectStore(testStoreName);
        var key = await objectStore.put({});
        await objectStore.delete(key);
        await transaction.completed;
      });

      test('get_delete', () async {
        await dbSetUp();
        var transaction = db.transaction(testStoreName, idbModeReadWrite);
        var objectStore = transaction.objectStore(testStoreName);
        var key = await objectStore
            .put({'name': 'name', 'delete': true, 'dirty': false});
        await transaction.completed;

        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction.objectStore(testStoreName);
        await objectStore.getObject(key);

        // wait crashes on ie
        if (!ctx.isIdbNoLazy) {
          await Future<void>.value();
        }
        await objectStore.delete(key);
        await transaction.completed;
      });
    });
  });
}
