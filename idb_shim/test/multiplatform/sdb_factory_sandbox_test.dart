import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/common/mixin.dart' show SdbFactorySandbox;
import 'package:path/path.dart';
import 'package:test/test.dart';

var testStore = SdbStoreRef<int, SdbModel>('test');

void main() {
  group('sdb_factory_sandbox', () {
    test('open/delete', () async {
      var factory = newSdbFactoryMemory();
      var options = SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(
          stores: [testStore.schema(autoIncrement: true)],
        ),
      );
      var sandboxed = factory.sandbox(path: 'sandbox');
      var sandboxed2 = sandboxed.sandbox(path: 'subsandbox');
      expect(
        await sandboxed.getDatabaseFullPath('test'),
        join('sandbox', 'test'),
      );
      expect(
        await sandboxed2.getDatabaseFullPath('test'),
        join('sandbox', 'subsandbox', 'test'),
      );
      var db = await sandboxed.openDatabase('test.db', options: options);
      var key = await testStore.add(db, {'value': 1});
      await db.close();

      // The database is visible in the delegate factory below the sandbox
      // path.
      db = await factory.openDatabase(
        join('sandbox', 'test.db'),
        options: options,
      );
      var snapshot = await testStore.record(key).get(db);
      expect(snapshot!.value, {'value': 1});
      await db.close();

      await sandboxed.deleteDatabase('test.db');
      db = await factory.openDatabase(
        join('sandbox', 'test.db'),
        options: options,
      );
      expect(await testStore.record(key).get(db), isNull);
      await db.close();
    });

    test('escape throws', () async {
      var sandboxed = newSdbFactoryMemory().sandbox(path: 'root');
      expect(
        () => sandboxed.openDatabase(join('..', 'other.db')),
        throwsArgumentError,
      );
    });
    test('delegatePath', () {
      var sandboxed =
          newSdbFactoryMemory().sandbox(path: 'root') as SdbFactorySandbox;
      expect(
        () => sandboxed.delegatePath(join('..', 'other.db')),
        throwsArgumentError,
      );
      expect(sandboxed.delegatePath('my.db'), endsWith(join('root', 'my.db')));
    });
  });
}
