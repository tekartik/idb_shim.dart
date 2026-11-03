import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/common/common_database.dart';
import 'package:idb_shim/src/sembast/sembast_database.dart';
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
    test('delegatePath', () {
      var sandboxed =
          newIdbFactoryMemory().sandbox(path: 'root') as IdbFactorySandbox;
      expect(
        () => sandboxed.delegatePath(join('..', 'other.db')),
        throwsArgumentError,
      );
      expect(sandboxed.delegatePath('my.db'), endsWith(join('root', 'my.db')));
    });

    test('database name and factory', () async {
      var idbFactory = newIdbFactoryMemory();
      var sandboxed = idbFactory.sandbox(path: 'sandbox');
      Database? upgradeDatabase;
      String? upgradeName;
      var db = await sandboxed.open(
        'test.db',
        version: 1,
        onUpgradeNeeded: (event) {
          upgradeDatabase = event.database;
          upgradeName = event.database.name;
          event.database.createObjectStore('store');
        },
      );
      // The name opened in the sandbox, like a native database.
      expect(db.name, 'test.db');
      expect(upgradeName, 'test.db');
      expect(identical(upgradeDatabase, db), isTrue);
      expect(db.factory, sandboxed);
      // Still the database of the implementation (it can be cast).
      expect(db, isA<DatabaseSembast>());
      expect(
        (idbFactory as IdbFactorySembast).getSembastDatabase(db),
        isNotNull,
      );
      expect((db as IdbDatabaseBase).implName, join('sandbox', 'test.db'));
      expect(
        await sandboxed.getDatabaseFullPath(db.name),
        join('sandbox', 'test.db'),
      );

      // Usable as is.
      var txn = db.transaction('store', idbModeReadWrite);
      expect(txn.database.name, 'test.db');
      await txn.objectStore('store').put('value', 1);
      await txn.completed;
      db.close();

      // Reopened with its name.
      db = await sandboxed.open(db.name);
      expect(db.version, 1);
      txn = db.transaction('store', idbModeReadOnly);
      expect(await txn.objectStore('store').getObject(1), 'value');
      await txn.completed;
      db.close();
      await sandboxed.deleteDatabase('test.db');
    });
  });
}
