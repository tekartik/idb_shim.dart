// Regression tests of the 2026-11-09 review (found on the sembast backend,
// the same behavior is expected from every implementation).
library;

import 'package:idb_shim/idb_jdb.dart';
import 'package:idb_shim/utils/idb_utils.dart';

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

/// The record count of the autoAdvance cursor test: big on the plain sembast
/// factories (the recursive walk overflowed the stack from about 30000
/// records), a smoke test elsewhere (native, sqflite, and sembast on jdb,
/// whose writes are slow).
int _manyRecordsCount(TestContext ctx) {
  var isSembastJdb =
      ctx is SembastTestContext && ctx.sdbFactory is DatabaseFactoryJdb;
  return (ctx.isIdbSembast && !isSembastJdb) ? 50000 : 2000;
}

void defineTests(TestContext ctx) {
  final factory = ctx.factory;

  Future<List<Object>> getAll(Database db, String storeName) async {
    var txn = db.transaction(storeName, idbModeReadOnly);
    var values = await txn.objectStore(storeName).getAll();
    await txn.completed;
    return values;
  }

  group('review_regression', () {
    test('getAll and getAllKeys with a count in a transaction', () async {
      var dbName = ctx.dbName;
      await factory.deleteDatabase(dbName);
      var db = await factory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (e) async {
          var store = e.database.createObjectStore('s');
          await store.put('v1', 1);
          await store.put('v2', 2);
          await store.put('v3', 3);
        },
      );
      var txn = db.transaction('s', idbModeReadWrite);
      var store = txn.objectStore('s');
      await store.put('v3b', 3);
      expect(await store.getAllKeys(null, 2), [1, 2]);
      expect(await store.getAll(null, 2), ['v1', 'v2']);
      await txn.completed;
      db.close();
    });

    test('autoAdvance cursor on many records', () async {
      var count = _manyRecordsCount(ctx);
      var dbName = ctx.dbName;
      await factory.deleteDatabase(dbName);
      var db = await factory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (e) {
          e.database.createObjectStore('s', autoIncrement: true);
        },
      );
      var txn = db.transaction('s', idbModeReadWrite);
      var store = txn.objectStore('s');
      for (var i = 0; i < count; i++) {
        store.put(i).ignore();
      }
      await txn.completed;
      txn = db.transaction('s', idbModeReadOnly);
      var keys = await cursorToKeyList(
        txn.objectStore('s').openKeyCursor(autoAdvance: true),
      );
      await txn.completed;
      expect(keys.length, count);
      db.close();
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cursor delete in a read-only transaction', () async {
      var dbName = ctx.dbName;
      await factory.deleteDatabase(dbName);
      var db = await factory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (e) async {
          var store = e.database.createObjectStore('s');
          await store.put('v1', 1);
        },
      );
      var txn = db.transaction('s', idbModeReadOnly);
      Object? error;
      await txn.objectStore('s').openCursor(autoAdvance: false).listen((
        cursor,
      ) async {
        try {
          await cursor.delete();
        } catch (e) {
          error = e;
        }
        cursor.next();
      }).asFuture<void>();
      try {
        await txn.completed;
      } catch (_) {}
      expect(error, isNotNull);
      expect(isTransactionReadOnlyError(error!), isTrue, reason: '$error');
      expect(await getAll(db, 's'), ['v1']);
      db.close();
    });

    test('store deleted and created again in the same upgrade', () async {
      var dbName = ctx.dbName;
      await factory.deleteDatabase(dbName);
      var db = await factory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (e) async {
          var store = e.database.createObjectStore('s', autoIncrement: true);
          await store.put('old');
        },
      );
      db.close();
      int? countInUpgrade;
      db = await factory.open(
        dbName,
        version: 2,
        onUpgradeNeeded: (e) async {
          e.database.deleteObjectStore('s');
          var store = e.database.createObjectStore('s', autoIncrement: true);
          countInUpgrade = await store.count();
          await store.put('new');
        },
      );
      expect(countInUpgrade, 0);
      expect(await getAll(db, 's'), ['new']);
      db.close();
      // Still there once reopened.
      db = await factory.open(dbName);
      expect(await getAll(db, 's'), ['new']);
      db.close();
    });

    test('store deleted in an upgrade', () async {
      var dbName = ctx.dbName;
      await factory.deleteDatabase(dbName);
      var db = await factory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (e) async {
          var store = e.database.createObjectStore('s', autoIncrement: true);
          await store.put('old');
        },
      );
      db.close();
      db = await factory.open(
        dbName,
        version: 2,
        onUpgradeNeeded: (e) {
          e.database.deleteObjectStore('s');
        },
      );
      expect(db.objectStoreNames, isEmpty);
      db.close();
      db = await factory.open(
        dbName,
        version: 3,
        onUpgradeNeeded: (e) {
          e.database.createObjectStore('s', autoIncrement: true);
        },
      );
      expect(await getAll(db, 's'), isEmpty);
      db.close();
    });

    group('cursor on an index of a store with an array key path', () {
      Future<Database> openDb() async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        return factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) async {
            var store = e.database.createObjectStore('s', keyPath: ['a', 'b']);
            store.createIndex('i', 'tags', multiEntry: true);
            await store.put({
              'a': 1,
              'b': 1,
              'tags': ['x', 'y'],
            });
          },
        );
      }

      test('delete', () async {
        var db = await openDb();
        var txn = db.transaction('s', idbModeReadWrite);
        var visited = <Object>[];
        await txn
            .objectStore('s')
            .index('i')
            .openCursor(autoAdvance: false)
            .listen((cursor) async {
              visited.add(cursor.key);
              if (visited.length == 1) {
                await cursor.delete();
              }
              cursor.next();
            })
            .asFuture<void>();
        await txn.completed;
        // The record of 'y' was deleted.
        expect(visited, ['x']);
        db.close();
      });

      test('update', () async {
        var db = await openDb();
        var txn = db.transaction('s', idbModeReadWrite);
        var values = <Map>[];
        await txn
            .objectStore('s')
            .index('i')
            .openCursor(autoAdvance: false)
            .listen((cursor) async {
              values.add(cursor.value as Map);
              if (values.length == 1) {
                await cursor.update({...cursor.value as Map, 'updated': true});
              }
              cursor.next();
            })
            .asFuture<void>();
        await txn.completed;
        expect(values.length, 2);
        expect(values[1]['updated'], isTrue);
        db.close();
      });
    });

    for (var field in ['_key', '_value']) {
      test('index on a field named $field', () async {
        var dbName = ctx.dbName;
        await factory.deleteDatabase(dbName);
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) async {
            var store = e.database.createObjectStore('s', autoIncrement: true);
            store.createIndex('i', field);
            store.createIndex('u', field, unique: true);
            await store.put({field: 'a'});
          },
        );
        var txn = db.transaction('s', idbModeReadWrite);
        var store = txn.objectStore('s');
        var index = store.index('i');
        expect(await index.get('a'), {field: 'a'});
        expect(await index.getKey('a'), 1);
        expect(await index.count(), 1);
        expect(await index.getAllKeys(KeyRange.only('a')), [1]);
        try {
          await store.put({field: 'a'});
          fail('should fail');
        } on DatabaseError catch (_) {}
        try {
          await txn.completed;
        } catch (_) {}
        db.close();
      });
    }

    test('store with an array key path on a field named _key', () async {
      var dbName = ctx.dbName;
      await factory.deleteDatabase(dbName);
      var db = await factory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (e) async {
          var store = e.database.createObjectStore('s', keyPath: ['_key', 'b']);
          await store.put({'_key': 'k', 'b': 1, 'v': 1});
        },
      );
      var txn = db.transaction('s', idbModeReadWrite);
      var store = txn.objectStore('s');
      expect(await store.getObject(['k', 1]), {'_key': 'k', 'b': 1, 'v': 1});
      expect(await store.count(KeyRange.only(['k', 1])), 1);
      await txn.completed;
      db.close();
    });
  });
}
