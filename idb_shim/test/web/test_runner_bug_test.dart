library;

import 'package:idb_shim/src/sembast/sembast_factory.dart';

import '../idb_test_common.dart';

void main() {
  var idbFactory = idbFactoryMemoryFs;
  // test('solo', () {}, solo: true);
  test(
    'bug',
    () async {
      // Turn on dev logs
      sembastDebug = true;
      var dbName = 'bug.db';
      try {
        try {
          await idbFactory.deleteDatabase(dbName);
        } catch (_) {}

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName);
        }

        var db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: onUpgradeNeeded,
        );

        db.close();
      } finally {
        sembastDebug = false;
      }
    },
    skip: true,
  ); // Was setup for dart2 2.0.0-dev63 for an existing dart2 optimization
}
