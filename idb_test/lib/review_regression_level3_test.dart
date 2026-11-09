// Regression tests of the 2026-11-09 level 3 review (found on the sqflite
// backend, idb_sqflite, the same behavior is expected from every
// implementation).
library;

import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_shim/idb_jdb.dart';
import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/common/common_factory_sandbox.dart' // ignore: implementation_imports
    show idbFactorySandboxDelegate;

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

/// True for the idb_sqflite factory, possibly wrapped in a logger or a
/// sandbox.
bool _isIdbSqflite(TestContext ctx) {
  var factory = ctx.factory;
  while (true) {
    if (factory is IdbFactoryLogger) {
      factory = factory.factory;
    } else if (factory is IdbFactorySandbox) {
      factory = idbFactorySandboxDelegate(factory);
    } else {
      break;
    }
  }
  return factory.name == 'sqflite';
}

void defineTests(TestContext ctx) {
  final factory = ctx.factory;
  final isIdbSqflite = _isIdbSqflite(ctx);
  final isSembastJdb =
      ctx is SembastTestContext && ctx.sdbFactory is DatabaseFactoryJdb;
  final isLogger = factory is IdbFactoryLogger;

  Future<List<Object>> getAll(Database db, String storeName) async {
    var txn = db.transaction(storeName, idbModeReadOnly);
    var values = await txn.objectStore(storeName).getAll();
    await txn.completed;
    return values;
  }

  Future<int> indexCount(Database db, String storeName, String index) async {
    var txn = db.transaction(storeName, idbModeReadOnly);
    var count = await txn.objectStore(storeName).index(index).count();
    await txn.completed;
    return count;
  }

  group('review_regression_level3', () {
    // Several schema changes with no request between them
    group('schema changes in one go', () {
      test('store created then deleted', () async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            e.database.createObjectStore('s');
            e.database.deleteObjectStore('s');
          },
        );
        expect(db.objectStoreNames, isEmpty);
        db.close();
        if (!ctx.isInMemory) {
          db = await factory.open(dbName, version: 1);
          expect(db.objectStoreNames, isEmpty);
          db.close();
        }
      });

      test('store with an index created then deleted', () async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            var store = e.database.createObjectStore('s');
            store.createIndex('i', 'a');
            e.database.deleteObjectStore('s');
          },
        );
        expect(db.objectStoreNames, isEmpty);
        db.close();
      });

      test('index deleted then its store deleted', () async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            e.database.createObjectStore('s').createIndex('i', 'a');
          },
        );
        db.close();
        db = await factory.open(
          dbName,
          version: 2,
          onUpgradeNeeded: (e) {
            e.transaction.objectStore('s').deleteIndex('i');
            e.database.deleteObjectStore('s');
          },
        );
        expect(db.objectStoreNames, isEmpty);
        db.close();
        // Same store and index again
        db = await factory.open(
          dbName,
          version: 3,
          onUpgradeNeeded: (e) {
            e.database.createObjectStore('s').createIndex('i', 'a');
          },
        );
        var txn = db.transaction('s', idbModeReadWrite);
        await txn.objectStore('s').put({'a': 1}, 1);
        await txn.completed;
        expect(await indexCount(db, 's', 'i'), 1);
        db.close();
      });

      test('store deleted and created again in the first upgrade', () async {
        // A fresh install running every step of the migrations: version 1
        // creates the store, version 2 creates it again.
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        var db = await factory.open(
          dbName,
          version: 2,
          onUpgradeNeeded: (e) {
            var db = e.database;
            if (e.oldVersion < 1) {
              db.createObjectStore('s').createIndex('i', 'a');
            }
            if (e.oldVersion < 2) {
              db.deleteObjectStore('s');
              db.createObjectStore('s').createIndex('i', 'a');
            }
          },
        );
        var txn = db.transaction('s', idbModeReadWrite);
        await txn.objectStore('s').put({'a': 2}, 2);
        await txn.completed;
        expect(await indexCount(db, 's', 'i'), 1);
        db.close();
        if (!ctx.isInMemory) {
          db = await factory.open(dbName, version: 2);
          expect(db.objectStoreNames, ['s']);
          expect(await indexCount(db, 's', 'i'), 1);
          db.close();
        }
      });

      test('index deleted and created again on another key path', () async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) async {
            var store = e.database.createObjectStore('s');
            store.createIndex('i', 'a');
            await store.put({'a': 1, 'b': 2}, 1);
          },
        );
        db.close();
        db = await factory.open(
          dbName,
          version: 2,
          onUpgradeNeeded: (e) {
            var store = e.transaction.objectStore('s');
            store.deleteIndex('i');
            store.createIndex('i', 'b');
          },
        );
        var txn = db.transaction('s', idbModeReadOnly);
        var index = txn.objectStore('s').index('i');
        expect(index.keyPath, 'b');
        expect(await index.get(2), {'a': 1, 'b': 2});
        expect(await index.get(1), isNull);
        await txn.completed;
        db.close();
      });
    });

    test(
      'failed upgrade after a write is not committed',
      () async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        try {
          await factory.open(
            dbName,
            version: 1,
            onUpgradeNeeded: (e) async {
              var store = e.database.createObjectStore('s');
              await store.put('old', 1);
              throw StateError('upgrade failed');
            },
          );
          fail('should fail');
        } on StateError catch (e) {
          expect(e.message, 'upgrade failed');
        }
        int? oldVersion;
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            oldVersion = e.oldVersion;
            e.database.createObjectStore('s');
          },
        );
        expect(oldVersion, 0);
        expect(await getAll(db, 's'), isEmpty);
        db.close();
      },
      skip: isSembastJdb
          ? 'idb_shim sembast backend on a jdb factory keeps the write of the failed upgrade (level 3 review finding)'
          : null,
    );

    test(
      'transaction on a closed database fails',
      () async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) => e.database.createObjectStore('s'),
        );
        db.close();
        Future<void> read() async {
          var txn = db.transaction('s', idbModeReadOnly);
          await txn.objectStore('s').getObject(1);
        }

        Object? error;
        try {
          await read().timeout(const Duration(seconds: 10));
        } catch (e) {
          error = e;
        }
        expect(error, isNotNull);
        expect(error, isNot(isA<TimeoutException>()));
      },
      skip: isLogger
          ? 'the idb_shim logger getObject returns the error as the value (level 3 review finding)'
          : null,
    );

    test(
      'aborted transaction nobody waits for is not an uncaught error',
      () async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) async {
            await e.database.createObjectStore('s').put('a', 1);
          },
        );
        var uncaught = <Object>[];
        Object? addError;
        await runZonedGuarded(
          () async {
            var txn = db.transaction('s', idbModeReadWrite);
            try {
              await txn.objectStore('s').add('b', 1);
            } catch (e) {
              addError = e;
            }
            // txn.completed not awaited
            await Future<void>.delayed(const Duration(milliseconds: 100));
          },
          (e, st) {
            uncaught.add(e);
          },
        );
        expect(addError, isNotNull);
        expect(uncaught, isEmpty);
        expect(await getAll(db, 's'), ['a']);
        db.close();
      },
    );

    // An index key path giving a value that is not a valid key: the record
    // is not indexed, the write succeeds.
    group('index value not a key', () {
      Future<int> putAndCount(
        Object fieldValue, {
        bool multiEntry = false,
      }) async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            e.database
                .createObjectStore('s')
                .createIndex('i', 'f', multiEntry: multiEntry);
          },
        );
        try {
          var txn = db.transaction('s', idbModeReadWrite);
          await txn.objectStore('s').put({'f': fieldValue}, 1);
          await txn.completed;
          expect(await getAll(db, 's'), [
            {'f': fieldValue},
          ]);
          return await indexCount(db, 's', 'i');
        } finally {
          db.close();
        }
      }

      test('map', () async {
        expect(await putAndCount({'a': 1}), 0);
      });
      test('multiEntry null and map items', () async {
        expect(
          await putAndCount([
            'a',
            null,
            {'b': 1},
          ], multiEntry: true),
          1,
        );
      });
      test(
        'bool',
        () async {
          expect(await putAndCount(true), 0);
        },
        skip: isIdbSqflite
            ? 'idb_sqflite indexes a bool as the int 1 (level 3 review, needs a decision)'
            : null,
      );
      test(
        'date is a key',
        () async {
          expect(await putAndCount(DateTime.utc(2024)), 1);
        },
        skip: isIdbSqflite
            ? 'idb_sqflite fails to write an indexed DateTime (level 3 review, needs a key encoding)'
            : null,
      );
    });

    group('sdb', () {
      var store = SdbStoreRef<int, SdbModel>('s');
      var index = store.index<int>('i');

      Future<SdbDatabase> openDb() async {
        var sdbFactory = sdbFactoryFromIdb(factory);
        var dbName = ctx.dbName;
        await sdbFactory.deleteDatabase(dbName);
        var db = await sdbFactory.openDatabase(
          dbName,
          options: SdbOpenDatabaseOptions(
            version: 1,
            schema: SdbDatabaseSchema(
              stores: [
                store.schema(indexes: [index.schema(keyPath: 'a')]),
              ],
            ),
          ),
        );
        await store.record(1).put(db, {'a': 1});
        return db;
      }

      test('row update in a read-only store iterate fails', () async {
        var db = await openDb();
        Object? error;
        try {
          await store.iterate(
            db,
            onRow: (row) async {
              await row.update({'a': 2});
              return true;
            },
          );
        } catch (e) {
          error = e;
        }
        expect(error, isNotNull);
        expect((await store.record(1).get(db))!.value, {'a': 1});
        await db.close();
      });

      test('row update in a read-only index iterate fails', () async {
        var db = await openDb();
        Object? error;
        try {
          await index.iterate(
            db,
            onRow: (row) async {
              await row.update({'a': 2});
              return true;
            },
          );
        } catch (e) {
          error = e;
        }
        expect(error, isNotNull);
        expect((await store.record(1).get(db))!.value, {'a': 1});
        await db.close();
      });
    });
  });
}
