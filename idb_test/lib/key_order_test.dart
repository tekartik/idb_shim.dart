library;

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

/// Key order, multiEntry and array key path behaviors, the same on every
/// implementation as on native IndexedDB.
void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  group('key_order', () {
    test('cmp', () {
      // Arrays compared item by item, then by length
      expect(idbFactory.cmp([1], [1, 2]), -1);
      expect(idbFactory.cmp([1, 2], [1]), 1);
      // number < string < array
      expect(idbFactory.cmp(1, 'a'), -1);
      expect(idbFactory.cmp('a', [1]), -1);
      expect(idbFactory.cmp([1], 1), 1);
    });

    test('KeyRange.contains', () {
      var range = KeyRange.bound([1], [1, 5]);
      // ignore: invalid_use_of_protected_member
      bool contains(Object key) => range.contains(key);
      expect(contains([1]), isTrue);
      expect(contains([1, 2]), isTrue);
      expect(contains([0]), isFalse);
      expect(contains([1, 6]), isFalse);
      // A number is before any array
      expect(contains(2), isFalse);
    });

    late Database db;

    Future<T> readOnly<T>(
      String storeName,
      Future<T> Function(ObjectStore store) action,
    ) async {
      var txn = db.transaction(storeName, idbModeReadOnly);
      var result = await action(txn.objectStore(storeName));
      await txn.completed;
      return result;
    }

    Future<List<String>> cursorEntries(
      Index index, {
      KeyRange? range,
      String? direction,
    }) async {
      var entries = <String>[];
      await index
          .openCursor(range: range, direction: direction, autoAdvance: true)
          .listen((cursor) => entries.add('${cursor.key}:${cursor.primaryKey}'))
          .asFuture<void>();
      return entries;
    }

    group('multiEntry', () {
      setUp(() async {
        var dbName = ctx.dbName;
        await idbFactory.deleteDatabase(dbName);
        db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            var store = e.database.createObjectStore('s');
            store.createIndex('m', 'v', multiEntry: true);
            store.createIndex('k', 'k');
            store.createIndex('u', 'u', multiEntry: true, unique: true);
          },
        );
        var txn = db.transaction('s', idbModeReadWrite);
        var store = txn.objectStore('s');
        await store.put({
          'v': ['a', 'z'],
          'k': 1,
        }, 1);
        await store.put({
          'v': ['x', 'y'],
          'k': 'b',
        }, 2);
        await store.put({
          'v': 'c',
          'k': [1],
        }, 3);
        await txn.completed;
      });
      tearDown(() {
        db.close();
      });

      test('range per entry', () async {
        Index index(ObjectStore store) => store.index('m');
        expect(
          await readOnly(
            's',
            (store) =>
                cursorEntries(index(store), range: KeyRange.lowerBound('m')),
          ),
          ['x:2', 'y:2', 'z:1'],
        );
        expect(
          await readOnly(
            's',
            (store) =>
                cursorEntries(index(store), range: KeyRange.upperBound('b')),
          ),
          ['a:1'],
        );
        // count, getAll and getAllKeys count entries, not records
        expect(
          await readOnly(
            's',
            (store) => index(store).count(KeyRange.lowerBound('m')),
          ),
          3,
        );
        expect(
          await readOnly(
            's',
            (store) => index(store).count(KeyRange.upperBound('b')),
          ),
          1,
        );
        expect(
          await readOnly(
            's',
            (store) => index(store).getAllKeys(KeyRange.lowerBound('m')),
          ),
          [2, 2, 1],
        );
        expect(
          (await readOnly(
            's',
            (store) => index(store).getAll(KeyRange.lowerBound('m')),
          )).length,
          3,
        );
      });

      test('mixed key types', () async {
        Index index(ObjectStore store) => store.index('k');
        // number < string < array
        expect(
          await readOnly(
            's',
            (store) =>
                cursorEntries(index(store), range: KeyRange.lowerBound(0)),
          ),
          ['1:1', 'b:2', '[1]:3'],
        );
        expect(
          await readOnly(
            's',
            (store) => index(store).count(KeyRange.upperBound('a')),
          ),
          1,
        );
        expect(
          await readOnly(
            's',
            (store) => index(store).count(KeyRange.lowerBound('a')),
          ),
          2,
        );
      });

      test('unique', () async {
        var txn = db.transaction('s', idbModeReadWrite);
        var store = txn.objectStore('s');
        await store.put({
          'u': ['u1', 'u2'],
        }, 10);
        // Same record, same entries
        await store.put({
          'u': ['u2', 'u1'],
        }, 10);
        await txn.completed;
        txn = db.transaction('s', idbModeReadWrite);
        store = txn.objectStore('s');
        try {
          await store.put({
            'u': ['u3', 'u2'],
          }, 11);
          fail('should fail');
        } catch (e) {
          expect(e, isNot(isA<TestFailure>()));
        }
        try {
          await txn.completed;
        } catch (_) {
          // Aborted on native
        }
        expect(await readOnly('s', (store) => store.getObject(11)), isNull);
      });
    });

    group('index order', () {
      setUp(() async {
        var dbName = ctx.dbName;
        await idbFactory.deleteDatabase(dbName);
        db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            var store = e.database.createObjectStore('s');
            store.createIndex('i', 'i');
          },
        );
        var txn = db.transaction('s', idbModeReadWrite);
        var store = txn.objectStore('s');
        await store.put({'i': 'b'}, 2);
        await store.put({'i': 'a'}, 3);
        await store.put({'i': 'b'}, 1);
        await store.put({'i': 'a'}, 4);
        await txn.completed;
      });
      tearDown(() {
        db.close();
      });

      test('equal keys by primary key', () async {
        expect(
          await readOnly('s', (store) => cursorEntries(store.index('i'))),
          ['a:3', 'a:4', 'b:1', 'b:2'],
        );
        expect(
          await readOnly(
            's',
            (store) =>
                cursorEntries(store.index('i'), direction: idbDirectionPrev),
          ),
          ['b:2', 'b:1', 'a:4', 'a:3'],
        );
      });

      test('get and getKey with a key range', () async {
        var range = KeyRange.lowerBound('b');
        expect(
          await readOnly('s', (store) => store.index('i').getKey(range)),
          1,
        );
        expect(await readOnly('s', (store) => store.index('i').get(range)), {
          'i': 'b',
        });
        expect(
          await readOnly(
            's',
            (store) => store.index('i').getKey(KeyRange.lowerBound('c')),
          ),
          isNull,
        );
      });
    });

    group('array key path', () {
      setUp(() async {
        var dbName = ctx.dbName;
        await idbFactory.deleteDatabase(dbName);
        db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            var store = e.database.createObjectStore('s', keyPath: ['a', 'b']);
            store.createIndex('u', 'u', unique: true);
            store.createIndex('i', 'i');
          },
        );
        var txn = db.transaction('s', idbModeReadWrite);
        var store = txn.objectStore('s');
        await store.put({'a': 2, 'b': 1, 'u': 'u2', 'i': 'x'});
        await store.put({'a': 1, 'b': 2, 'u': 'u1', 'i': 'x'});
        await store.put({'a': 1, 'b': 1, 'u': 'u0', 'i': 'y'});
        await txn.completed;
      });
      tearDown(() {
        db.close();
      });

      test('keys and order', () async {
        expect(await readOnly('s', (store) => store.getAllKeys()), [
          [1, 1],
          [1, 2],
          [2, 1],
        ]);
        expect(
          (await readOnly(
            's',
            (store) => store.getAll(),
          )).map((value) => (value as Map)['u']),
          ['u0', 'u1', 'u2'],
        );
        expect(await readOnly('s', (store) => store.getKey([1, 2])), [1, 2]);
        expect(await readOnly('s', (store) => store.count([1, 2])), 1);
        expect(
          await readOnly(
            's',
            (store) => store.count(KeyRange.lowerBound([1, 2])),
          ),
          2,
        );
        expect(
          (await readOnly(
            's',
            (store) => store.getAll(KeyRange.lowerBound([1, 2])),
          )).map((value) => (value as Map)['u']),
          ['u1', 'u2'],
        );
        expect(await readOnly('s', (store) => store.index('i').getKey('x')), [
          1,
          2,
        ]);
        expect(await readOnly('s', (store) => store.index('i').getAllKeys()), [
          [1, 2],
          [2, 1],
          [1, 1],
        ]);
      });

      test('put keeping a unique index value', () async {
        var txn = db.transaction('s', idbModeReadWrite);
        var store = txn.objectStore('s');
        await store.put({'a': 1, 'b': 2, 'u': 'u1', 'i': 'x2'});
        await txn.completed;
        expect(await readOnly('s', (store) => store.getObject([1, 2])), {
          'a': 1,
          'b': 2,
          'u': 'u1',
          'i': 'x2',
        });
      });
    });
  });
}
