@TestOn("browser")
library idb_shim.test_runner_client_native_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/utils/idb_utils.dart';

import '../idb_test_common.dart';
import '../test_runner.dart';
import 'idb_browser_test_common.dart';

void main() {
  group('native', () {
    if (idbFactoryNative != null) {
      IdbFactory idbFactory = idbFactoryNative;
      TestContext ctx = TestContext()..factory = idbFactory;

      // ie and idb special test marker
      ctx.isIdbIe = isIe;
      ctx.isIdbEdge = isEdge;
      ctx.isIdbSafari = isSafari;

      test('properties', () {
        expect(idbFactory.persistent, isTrue);
      });

      defineTests(ctx);

      group('keyPath', () async {
        // new
        String _dbName;
        // prepare for test
        Future _setupDeleteDb() async {
          _dbName = ctx.dbName;
          await idbFactory.deleteDatabase(_dbName);
        }

        test('multi', () async {
          await _setupDeleteDb();
          void _initializeDatabase(VersionChangeEvent e) {
            var db = e.database;
            var store =
                db.createObjectStore(testStoreName, autoIncrement: true);
            var index = store.createIndex('test', ['year', 'name']);
            expect(index.keyPath, ['year', 'name']);
          }

          var db = await idbFactory.open(_dbName,
              version: 1, onUpgradeNeeded: _initializeDatabase);

          Transaction transaction;
          ObjectStore objectStore;

          transaction = db.transaction(testStoreName, idbModeReadWrite);
          objectStore = transaction.objectStore(testStoreName);
          var index = objectStore.index('test');
          int record1Key =
              await objectStore.put({'year': 2018, 'name': 'John'}) as int;
          int record2Key =
              await objectStore.put({'year': 2018, 'name': 'Jack'}) as int;
          int record3Key =
              await objectStore.put({'year': 2017, 'name': 'John'}) as int;
          expect(index.keyPath, ['year', 'name']);
          expect(await index.getKey([2018, 'Jack']), record2Key);
          expect(await index.getKey([2018, 'John']), record1Key);
          expect(await index.getKey([2017, 'Jack']), isNull);
          expect(
              await index.get([2018, 'Jack']), {'year': 2018, 'name': 'Jack'});

          var list = await cursorToList(index.openCursor(autoAdvance: true));

          expect(list.length, 3);
          expect(list[0].value, {'year': 2017, 'name': 'John'});
          expect(list[0].primaryKey, record3Key);
          expect(list[0].key, [2017, 'John']);
          expect(list[2].key, [2018, 'John']);

          await transaction.completed;

          transaction = db.transaction(testStoreName, idbModeReadWrite);
          objectStore = transaction.objectStore(testStoreName);
          index = objectStore.index('test');

          list = await cursorToList(index.openCursor(
              range: KeyRange.bound([2018, 'Jack'], [2018, 'John']),
              autoAdvance: true));

          expect(list.length, 2);
          expect(list[0].primaryKey, record2Key);
          expect(list[1].primaryKey, record1Key);

          await transaction.completed;

          transaction = db.transaction(testStoreName, idbModeReadWrite);
          objectStore = transaction.objectStore(testStoreName);
          index = objectStore.index('test');

          list = await cursorToList(index.openCursor(
              range: KeyRange.upperBound([2018, 'Jack'], true),
              autoAdvance: true));

          expect(list.length, 1);
          expect(list[0].primaryKey, record3Key);
          expect(list[0].key, [2017, 'John']);

          await transaction.completed;

          db.close();
        },
            // keyPath as array not supported on IE
            skip: isEdge || isIe);
      });
    } else {
      test("idb native not supported", null, skip: "idb native not supported");
    }
  });
}
