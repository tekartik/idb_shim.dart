library idb_shim.test_runner_client_sembast_fs_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/sembast/sembast_factory.dart';

import '../idb_test_common.dart';

void main() {
  var idbFactory = idbMemoryFsFactory;
  test('bug', () async {
    // Turn on dev logs
    sembastDebug = true;
    var dbName = "bug.db";
    try {
      try {
        await idbFactory.deleteDatabase(dbName);
      } catch (_) {}

      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        db.createObjectStore(testStoreName);
      }

      print(
          " init $_initializeDatabase ${_initializeDatabase != null ? "NOT NULL" : "NULL"}");

      var db = await idbFactory.open(dbName,
          version: 1, onUpgradeNeeded: _initializeDatabase);

      db.close();
    } finally {
      sembastDebug = false;
    }
  },
      skip:
          true); // Was setup for dart2 2.0.0-dev63 for an existing dart2 optimization
}
