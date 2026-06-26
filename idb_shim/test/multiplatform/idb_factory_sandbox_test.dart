import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/sdb.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

var testStore = SdbStoreRef<int, SdbModel>('test');

void main() {
  group('idb_factory_sandbox', () {
    test('open/delete', () async {
      var idbFactory = newIdbFactoryMemory();
      var sandboxed = idbFactory.sandbox(path: join('sandbox', 'sub'));
      expect(sandboxed.persistent, idbFactory.persistent);
      var db = await sandboxed.open(
        'test.db',
        version: 1,
        onUpgradeNeeded: (event) {
          event.database.createObjectStore('store');
        },
      );
      expect(db.objectStoreNames, ['store']);
      db.close();

      // The database is visible in the delegate factory below the sandbox
      // path.
      db = await idbFactory.open(join('sandbox', 'sub', 'test.db'));
      expect(db.version, 1);
      expect(db.objectStoreNames, ['store']);
      db.close();

      await sandboxed.deleteDatabase('test.db');
      db = await idbFactory.open(join('sandbox', 'sub', 'test.db'));
      expect(db.objectStoreNames, isEmpty);
      db.close();
    });

    test('absolute path', () async {
      var idbFactory = newIdbFactoryMemory();
      var sandboxed = idbFactory.sandbox(path: 'sandbox');
      var db = await sandboxed.open('${separator}test.db');
      db.close();
      db = await idbFactory.open(join('sandbox', 'test.db'));
      expect(db.version, 1);
      db.close();
    });

    test('escape throws', () async {
      var sandboxed = newIdbFactoryMemory().sandbox(path: 'root');
      expect(() => sandboxed.open(join('..', 'other.db')), throwsArgumentError);
      expect(() => sandboxed.deleteDatabase('..'), throwsArgumentError);
    });

    test('no double sandbox', () async {
      var idbFactory = newIdbFactoryMemory();
      var sandboxed = idbFactory.sandbox(path: 'a').sandbox(path: 'b');
      expect(sandboxed.name, 'sandbox(${idbFactory.name}, ${join('a', 'b')})');
      var db = await sandboxed.open('test.db');
      db.close();
      db = await idbFactory.open(join('a', 'b', 'test.db'));
      expect(db.version, 1);
      db.close();
    });
  });

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
      expect(sandboxed.fullPath('test'), join('sandbox', 'test'));
      expect(
        sandboxed2.fullPath('test'),
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
  });
}
