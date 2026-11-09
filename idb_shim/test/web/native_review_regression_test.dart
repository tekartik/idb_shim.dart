// Regression tests of the 2026-11-09 review (native backend).
@TestOn('browser')
library;

import 'package:idb_shim/idb_browser.dart';
import 'package:test/test.dart';

void main() {
  group('native_review_regression', () {
    var factory = idbFactoryNative;

    test('onVersionChange event database', () async {
      var dbName = 'native_review_version_change.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (e) {
          e.database.createObjectStore('s');
        },
      );
      Object? error;
      Database? eventDatabase;
      db.onVersionChange.listen((e) {
        try {
          eventDatabase = e.database;
          expect(e.oldVersion, 1);
          expect(e.newVersion, 2);
        } catch (e) {
          error = e;
        }
        db.close();
      });
      var db2 = await factory.open(dbName, version: 2, onUpgradeNeeded: (e) {});
      db2.close();
      expect(error, isNull);
      expect(eventDatabase, same(db));
    });

    for (var isAsync in [false, true]) {
      test('failed upgrade is not committed (async: $isAsync)', () async {
        var dbName = 'native_review_upgrade_error_$isAsync.db';
        await factory.deleteDatabase(dbName);
        try {
          await factory.open(
            dbName,
            version: 1,
            onUpgradeNeeded: (e) async {
              var store = e.database.createObjectStore('s');
              if (isAsync) {
                await store.put('v', 1);
              }
              throw StateError('upgrade failure');
            },
          );
          fail('should fail');
        } on StateError catch (_) {}
        var upgradeCalled = false;
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            upgradeCalled = true;
            expect(e.oldVersion, 0);
            e.database.createObjectStore('s');
          },
        );
        var txn = db.transaction('s', idbModeReadOnly);
        var values = await txn.objectStore('s').getAll();
        await txn.completed;
        db.close();
        expect(upgradeCalled, isTrue);
        expect(values, isEmpty);
      });
    }
  });
}
