library;

import 'package:idb_shim/sdb.dart';
// ignore: implementation_imports
import 'package:idb_shim/src/common/mixin.dart' show SdbFactorySandbox;
// ignore: implementation_imports
import 'package:idb_shim/src/sdb/sdb_database.dart'
    show SdbDatabaseExtensionPrv;
import 'package:idb_shim/utils/idb_import_export.dart' as idb_utils;
import 'package:idb_shim/utils/sdb_import_export.dart' as sdb_utils;

import 'idb_test_common.dart';

void main() {
  idbSandboxTests(idbMemoryContext);
}

final _sdbStore = SdbStoreRef<int, String>('s');

/// A database opened through a sandbox of the factory of [ctx] is a database
/// of that factory (the same class, it can be cast), it reports the name
/// opened in the sandbox and the sandbox as factory, everywhere (upgrade
/// event, transactions), idb and sdb.
void idbSandboxTests(TestContext ctx) {
  var idbFactory = ctx.factory;
  var root = 'sandbox_test';

  group('sandbox', () {
    late IdbFactory sandboxed;
    setUp(() {
      sandboxed = idbFactory.sandbox(path: root);
    });

    /// The name in the factory of [ctx] of [name] in the sandbox.
    String fullName(String name) => idbFactory.pathContext.join(root, name);

    /// Open [name] in [factory] with the store `s` holding `1: 'v'`.
    Future<Database> openWithRecord(IdbFactory factory, String name) async {
      await factory.deleteDatabase(name);
      var db = await factory.open(
        name,
        version: 1,
        onUpgradeNeeded: (e) {
          e.database.createObjectStore('s');
        },
      );
      var txn = db.transaction('s', idbModeReadWrite);
      await txn.objectStore('s').put('v', 1);
      await txn.completed;
      return db;
    }

    Future<Object?> getRecord(Database db) async {
      var txn = db.transaction('s', idbModeReadOnly);
      var value = await txn.objectStore('s').getObject(1);
      await txn.completed;
      return value;
    }

    test('name, factory and class', () async {
      var name = 'open.db';
      await sandboxed.deleteDatabase(name);
      String? upgradeName;
      IdbFactory? upgradeFactory;
      var db = await sandboxed.open(
        name,
        version: 1,
        onUpgradeNeeded: (e) {
          upgradeName = e.database.name;
          upgradeFactory = e.database.factory;
          e.database.createObjectStore('s');
        },
      );
      try {
        expect(db.name, name);
        expect(db.factory, sandboxed);
        expect(upgradeName, name);
        expect(upgradeFactory, sandboxed);
        var txn = db.transaction('s', idbModeReadWrite);
        expect(txn.database.name, name);
        await txn.objectStore('s').put('v', 1);
        await txn.completed;
        expect(await getRecord(db), 'v');

        // The same class as a database opened without sandbox.
        var plainName = ctx.dbName;
        var plainDb = await openWithRecord(idbFactory, plainName);
        try {
          expect(db.runtimeType, plainDb.runtimeType);
          expect(plainDb.factory, idbFactory);
        } finally {
          plainDb.close();
          await idbFactory.deleteDatabase(plainName);
        }
      } finally {
        db.close();
      }
      await sandboxed.deleteDatabase(name);
    });

    test('full path', () async {
      var name = 'path.db';
      expect(
        await sandboxed.getDatabaseFullPath(name),
        await idbFactory.getDatabaseFullPath(fullName(name)),
      );
      var nested = sandboxed.sandbox(path: 'sub');
      expect(
        await nested.getDatabaseFullPath(name),
        await idbFactory.getDatabaseFullPath(
          idbFactory.pathContext.join(root, 'sub', name),
        ),
      );
    });

    test('nested sandbox', () async {
      var nested = sandboxed.sandbox(path: 'sub');
      var name = 'nested.db';
      var db = await openWithRecord(nested, name);
      try {
        expect(db.name, name);
        expect(db.factory, nested);
        expect(await getRecord(db), 'v');
      } finally {
        db.close();
      }
      await nested.deleteDatabase(name);
    });

    test(
      'reopen and delete with its name',
      () async {
        var name = 'reopen.db';
        var db = await openWithRecord(sandboxed, name);
        db.close();

        // Reopened with its name.
        db = await sandboxed.open(db.name);
        try {
          expect(db.name, name);
          expect(db.version, 1);
          expect(await getRecord(db), 'v');
        } finally {
          db.close();
        }

        // In the factory below the sandbox path.
        db = await idbFactory.open(fullName(name));
        try {
          expect(db.name, fullName(name));
          expect(db.factory, idbFactory);
          expect(await getRecord(db), 'v');
        } finally {
          db.close();
        }

        // Deleted with its name.
        await sandboxed.deleteDatabase(name);
        int? oldVersion;
        db = await sandboxed.open(
          name,
          version: 1,
          onUpgradeNeeded: (e) {
            oldVersion = e.oldVersion;
          },
        );
        db.close();
        expect(oldVersion, 0);
        await sandboxed.deleteDatabase(name);
      },
      // A memory database is not kept when closed.
      skip: ctx.isInMemory ? 'memory: not persistent across a reopen' : null,
    );

    test('export, import', () async {
      var name = 'export.db';
      var db = await openWithRecord(sandboxed, name);
      List<Object> lines;
      try {
        lines = await idb_utils.idbExportDatabaseLines(db);
      } finally {
        db.close();
      }
      var importedName = 'imported.db';
      var imported = await idb_utils.idbImportDatabase(
        lines,
        sandboxed,
        importedName,
      );
      try {
        expect(imported.name, importedName);
        expect(imported.factory, sandboxed);
        expect(imported.runtimeType, db.runtimeType);
        expect(await getRecord(imported), 'v');
        expect(await idb_utils.idbExportDatabaseLines(imported), lines);
      } finally {
        imported.close();
      }
      await sandboxed.deleteDatabase(name);
      await sandboxed.deleteDatabase(importedName);
    });

    group('sdb', () {
      late SdbFactory sdbSandboxed;
      setUp(() {
        sdbSandboxed = sdbFactoryFromIdb(idbFactory).sandbox(path: root);
      });

      Future<SdbDatabase> openSdbWithRecord(String name) async {
        await sdbSandboxed.deleteDatabase(name);
        var db = await sdbSandboxed.openDatabase(
          name,
          options: SdbOpenDatabaseOptions(
            version: 1,
            schema: SdbDatabaseSchema(stores: [_sdbStore.schema()]),
          ),
        );
        await _sdbStore.record(1).put(db, 'v');
        return db;
      }

      test('name and factory', () async {
        var name = 'sdb.db';
        var db = await openSdbWithRecord(name);
        try {
          expect(db.name, name);
          expect(db.factory, sdbSandboxed);
          expect(await _sdbStore.record(1).getValue(db), 'v');
          // Other tabs see the database by its name in the implementation.
          expect(
            db.dbInterface.crossTabName,
            (sdbSandboxed as SdbFactorySandbox).delegatePath(name),
          );
        } finally {
          await db.close();
        }
        await sdbSandboxed.deleteDatabase(name);
      });

      test(
        'reopen with its name',
        () async {
          var name = 'sdb_reopen.db';
          var db = await openSdbWithRecord(name);
          await db.close();
          db = await sdbSandboxed.openDatabase(db.name);
          try {
            expect(db.name, name);
            expect(db.version, 1);
            expect(await _sdbStore.record(1).getValue(db), 'v');
          } finally {
            await db.close();
          }
          await sdbSandboxed.deleteDatabase(name);
        },
        skip: ctx.isInMemory ? 'memory: not persistent across a reopen' : null,
      );

      test('export, import', () async {
        var name = 'sdb_export.db';
        var db = await openSdbWithRecord(name);
        List<Object> lines;
        try {
          lines = await sdb_utils.sdbExportDatabaseLines(db);
        } finally {
          await db.close();
        }
        var importedName = 'sdb_imported.db';
        var imported = await sdb_utils.sdbImportDatabase(
          lines,
          sdbSandboxed,
          importedName,
        );
        try {
          expect(imported.name, importedName);
          expect(imported.factory, sdbSandboxed);
          expect(await _sdbStore.record(1).getValue(imported), 'v');
        } finally {
          await imported.close();
        }
        await sdbSandboxed.deleteDatabase(name);
        await sdbSandboxed.deleteDatabase(importedName);
      });
    });
  });
}
