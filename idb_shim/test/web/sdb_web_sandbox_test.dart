@TestOn('browser')
library;

import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_sdb.dart';
import 'package:test/test.dart';

final _objectStore = SdbStoreRef('store');
void main() {
  group('sdb_native_sandbox', () {
    test('open/delete', () async {
      var sdbFactory = sdbFactoryWeb;
      var sandboxed = sdbFactory.sandbox(path: 'sandbox_test');
      var dbName = 'sandbox_web.db';
      expect(
        await sandboxed.getDatabaseFullPath(dbName),
        'sandbox_test/$dbName',
      );
      await sandboxed.deleteDatabase(dbName);
      var db = await sandboxed.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 2,
          schema: SdbDatabaseSchema(stores: [_objectStore.schema()]),
        ),
      );
      expect(db.storeNames, ['store']);
      await db.close();

      // The database is visible in the delegate factory below the sandbox
      // path.
      db = await sdbFactory.openDatabase('sandbox_test/$dbName');
      expect(db.version, 2);
      expect(db.storeNames, ['store']);
      await db.close();

      await sandboxed.deleteDatabase(dbName);
    }, skip: !idbFactoryNativeSupported);
  });
}
