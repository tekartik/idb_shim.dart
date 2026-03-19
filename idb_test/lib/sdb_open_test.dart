import 'package:idb_shim/sdb.dart';
import 'package:idb_test/sdb_test.dart';

import 'idb_test_common.dart';

void main() {
  idbSdbOpenTests(idbMemoryContext);
}

var testStore = SdbStoreRef<int, SdbModel>('test');

void idbSdbOpenTests(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);
  sdbOpenTests(SdbTestContext(factory));
}

/// Simple SDB test
void sdbOpenTests(SdbTestContext ctx) {
  var factory = ctx.factory;

  group('sdb_open', () {
    test('open/close', () async {
      var db = await factory.openDatabase('sdb_open_test.db');
      await db.close();
    });
    test('openDatabaseOnDowngradeDelete downgrade', () async {
      var dbName = 'sdb_downgrade_test.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabaseOnDowngradeDelete(
        dbName,
        version: 2,
        onVersionChange: (event) {
          var oldVersion = event.oldVersion;
          expect(oldVersion, 0);
          if (oldVersion < 2) {
            event.db.createStore(testStore);
          }
        },
      );
      expect(db.version, 2);
      await testStore.record(2).put(db, {'test': 2});
      expect((await testStore.findRecords(db)).keys, [2]);

      // Downgrade
      await db.close();
      db = await factory.openDatabaseOnDowngradeDelete(
        dbName,
        version: 1,
        onVersionChange: (event) {
          var oldVersion = event.oldVersion;
          if (oldVersion < 1) {
            event.db.createStore(testStore);
          }
        },
      );
      expect(db.version, 1);
      await testStore.record(1).put(db, {'test': 1});
      // First item (key 2) has been removed!
      expect((await testStore.findRecords(db)).keys, [1]);
      await db.close();
    });
    test('open schema and custom callback', () async {
      var dbName = 'sdb_schema_and_callback_test.db';
      await factory.deleteDatabase(dbName);
      var record = testStore.record(1);
      var db = await factory.openDatabaseOnDowngradeDelete(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [testStoreSchema]),
          onVersionChange: (event) async {
            await testStore.record(1).put(event.transaction, {'test': 1});
          },
        ),
      );
      expect(await record.getValue(db), {'test': 1});
    });
    test('openDatabaseOnDowngradeDelete schema downgrade', () async {
      var dbName = 'sdb_schema downgrade_test.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabaseOnDowngradeDelete(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 2,
          schema: SdbDatabaseSchema(stores: [testStoreSchema]),
        ),
      );
      expect(db.version, 2);
      await testStore.record(2).put(db, {'test': 2});
      expect((await testStore.findRecords(db)).keys, [2]);

      // Downgrade
      await db.close();
      db = await factory.openDatabaseOnDowngradeDelete(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [testStoreSchema]),
        ),
      );
      expect(db.version, 1);
      await testStore.record(1).put(db, {'test': 1});
      // First item (key 2) has been removed!
      expect((await testStore.findRecords(db)).keys, [1]);
      await db.close();
    });
  });
}
