@TestOn('browser')
library;

import 'package:idb_shim/idb_client_native.dart';
import 'package:test/test.dart';

void main() {
  group('idb_native_sandbox', () {
    test('open/delete', () async {
      var idbFactory = idbFactoryNative;
      var sandboxed = idbFactory.sandbox(path: 'sandbox_test');
      var dbName = 'sandbox_native.db';
      await sandboxed.deleteDatabase(dbName);
      var db = await sandboxed.open(
        dbName,
        version: 2,
        onUpgradeNeeded: (event) {
          event.database.createObjectStore('store');
        },
      );
      expect(db.objectStoreNames, ['store']);
      db.close();

      // The database is visible in the delegate factory below the sandbox
      // path.
      db = await idbFactory.open('sandbox_test/$dbName');
      expect(db.version, 2);
      expect(db.objectStoreNames, ['store']);
      db.close();

      await sandboxed.deleteDatabase(dbName);
    }, skip: !idbFactoryNativeSupported);

    test('escape throws', () async {
      var sandboxed = idbFactoryNative.sandbox(path: 'root');
      expect(() => sandboxed.open('../other.db'), throwsArgumentError);
    }, skip: !idbFactoryNativeSupported);
  });
}
