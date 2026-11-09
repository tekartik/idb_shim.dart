import 'package:idb_shim/sdb.dart';
import 'package:idb_test/sdb_test.dart';
import 'package:path/path.dart';

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
    test('open/close non existing', () async {
      var dbName = 'sdb_non_existing_test.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(dbName);
      await db.close();
      expect(db.version, 1);
      expect(db.openDatabaseOptions?.version, null);
    });
    test('open/close', () async {
      var dbName = 'sdb_open_test.db';
      var db = await factory.openDatabase(dbName);
      await db.close();
    });
    test('openDatabaseOnDowngradeDelete downgrade', () async {
      var dbName = 'sdb_downgrade_test.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabaseOnDowngradeDelete(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 2,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            expect(oldVersion, 0);
            if (oldVersion < 2) {
              event.db.createStore(testStore);
            }
          },
        ),
      );
      expect(db.version, 2);
      expect(db.openDatabaseOptions?.version, 2);

      await testStore.record(2).put(db, {'test': 2});
      expect((await testStore.findRecords(db)).keys, [2]);

      // Downgrade
      await db.close();
      db = await factory.openDatabaseOnDowngradeDelete(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(testStore);
            }
          },
        ),
      );
      expect(db.version, 1);
      expect(db.openDatabaseOptions?.version, 1);
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
    test('missing dir and absolute', () async {
      var dbName = join('missing_dir', 'sub', 'missing_dir.db');
      var path = await factory.getDatabaseFullPath(dbName);
      var db = await factory.openDatabase(path, options: testStoreOpenOptions);
      await db.close();
    });
    test('store deleted and created again in a version change', () async {
      // As idb, the records of the deleted store are gone (sdb_sembast kept
      // them, review of 2026-11-09).
      var dbName = 'sdb_open_delete_create_store.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          onVersionChange: (event) {
            event.db.createStore(testStore);
          },
        ),
      );
      await testStore.add(db, {'v': 'old'});
      await db.close();
      int? countInVersionChange;
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 2,
          onVersionChange: (event) async {
            event.db.deleteStore(testStore.name);
            event.db.createStore(testStore);
            countInVersionChange = await testStore.count(event.transaction);
            await testStore.add(event.transaction, {'v': 'new'});
          },
        ),
      );
      try {
        expect(countInVersionChange, 0);
        expect((await testStore.findRecords(db)).map((r) => r.value['v']), [
          'new',
        ]);
      } finally {
        await db.close();
      }
    });
  });
}
