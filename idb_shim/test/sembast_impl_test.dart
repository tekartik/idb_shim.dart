import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/utils/idb_import_export.dart';

import 'idb_test_common.dart';

void main() {
  group('sembast_impl', () {
    var idbFactory = idbFactoryMemory;
    group('key_path_auto', () {
      const keyPath = 'my_key';
      const dbName = 'sembast_impl_key_path_auto.db';
      late Database db;

      Transaction? transaction;
      late ObjectStore objectStore;

      void dbCreateTransaction() {
        transaction = db.transaction(testStoreName, idbModeReadWrite);
        objectStore = transaction!.objectStore(testStoreName);
      }

      // prepare for test
      Future setupDeleteDb() async {
        await idbFactory.deleteDatabase(dbName);
      }

      // generic tearDown
      Future dbTearDown() async {
        db.close();
      }

      Future dbSetUp() async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName,
              keyPath: keyPath, autoIncrement: true);
        }

        db = await idbFactory.open(dbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);
      }

      tearDown(dbTearDown);

      // Make sure the sembast record contains the key (additional test for issue #42)
      test('add_read_no_key', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {'test': 'test_value'};
        var key = await objectStore.add(value);
        expect(key, 1);
        expect(((await sdbExportDatabase(db))['stores'] as List)[1], {
          'name': 'test_store',
          'keys': [1],
          'values': [
            {'test': 'test_value', 'my_key': 1}
          ]
        });
      });

      test('add_read_explicit_key', () async {
        await dbSetUp();
        dbCreateTransaction();
        final value = {'test': 'test_value', keyPath: 1};
        var key = await objectStore.add(value);
        expect(key, 1);
        expect(((await sdbExportDatabase(db))['stores'] as List)[1], {
          'name': 'test_store',
          'keys': [1],
          'values': [
            {'test': 'test_value', 'my_key': 1}
          ]
        });
      });
    });
  });
}
