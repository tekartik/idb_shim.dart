@TestOn('browser')
library;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_native_html.dart';
import 'package:idb_shim/utils/idb_utils.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

import 'idb_browser_test_common.dart';

void main() {
  idbNativeFactoryTests(idbFactoryNative);
}

void idbNativeFactoryTests(IdbFactory idbFactoryNative) {
  group('native', () {
    if (idbFactoryNativeSupported) {
      final idbFactory = idbFactoryNative;
      final ctx = TestContext()..factory = idbFactory;

      // ie and idb special test marker
      ctx.isIdbIe = isIe;
      ctx.isIdbEdge = isEdge;
      ctx.isIdbSafari = isSafari;

      test('properties', () {
        expect(idbFactory.persistent, isTrue);
      });

      defineAllTests(ctx);

      group('keyPath', () {
        // new
        late String dbName;
        // prepare for test
        Future setupDeleteDb() async {
          dbName = ctx.dbName;
          await idbFactory.deleteDatabase(dbName);
        }

        test('multi', () async {
          await setupDeleteDb();
          late List onUpgradeIndexKeyPath;
          void onUpgradeNeeded(VersionChangeEvent e) {
            var db = e.database;
            var store =
                db.createObjectStore(testStoreName, autoIncrement: true);
            var index = store.createIndex('test', ['year', 'name']);
            onUpgradeIndexKeyPath = (index.keyPath as List).toList();
          }

          var db = await idbFactory.open(dbName,
              version: 1, onUpgradeNeeded: onUpgradeNeeded);
          expect(onUpgradeIndexKeyPath, ['year', 'name']);
          Transaction transaction;
          ObjectStore objectStore;

          transaction = db.transaction(testStoreName, idbModeReadWrite);
          objectStore = transaction.objectStore(testStoreName);
          var index = objectStore.index('test');
          final record1Key =
              await objectStore.put({'year': 2018, 'name': 'John'}) as int?;
          final record2Key =
              await objectStore.put({'year': 2018, 'name': 'Jack'}) as int?;
          final record3Key =
              await objectStore.put({'year': 2017, 'name': 'John'}) as int?;
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
      test('idb native not supported', () {}, skip: 'idb native not supported');
    }
  });
}
