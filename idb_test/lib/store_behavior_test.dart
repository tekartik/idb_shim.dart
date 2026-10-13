library;

import 'package:idb_shim/idb_jdb.dart';

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

/// True for a ConstraintError (native) or the equivalent of the other
/// implementations (a key already existing).
bool _isConstraintError(Object e) {
  var message = e.toString().toLowerCase();
  return message.contains('constraint') || message.contains('already exists');
}

/// True for an idb on a sembast jdb database.
bool _isSembastJdb(TestContext ctx) =>
    ctx is SembastTestContext && ctx.sdbFactory is DatabaseFactoryJdb;

/// Store and cursor behaviors, the same on every implementation as on native
/// IndexedDB.
void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  group('store_behavior', () {
    late Database db;

    Future<void> openDb(void Function(Database db) onUpgrade) async {
      var dbName = ctx.dbName;
      await idbFactory.deleteDatabase(dbName);
      db = await idbFactory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (e) => onUpgrade(e.database),
      );
    }

    tearDown(() {
      db.close();
    });

    /// Runs [action] in a transaction, ignoring an aborted transaction.
    Future<T> inTxn<T>(
      String mode,
      Future<T> Function(ObjectStore store) action,
    ) async {
      var txn = db.transaction('s', mode);
      try {
        return await action(txn.objectStore('s'));
      } finally {
        try {
          await txn.completed;
        } catch (_) {}
      }
    }

    test('clear also clears the indexes', () async {
      await openDb((db) {
        db.createObjectStore('s').createIndex('v', 'v');
      });
      await inTxn(idbModeReadWrite, (store) async {
        await store.put({'v': 'a'}, 1);
        await store.put({'v': 'b'}, 2);
      });
      await inTxn(idbModeReadWrite, (store) => store.clear());
      await inTxn(idbModeReadWrite, (store) async {
        var index = store.index('v');
        expect(await index.count(), 0);
        await store.put({'v': 'c'}, 10);
        expect(await index.getKey('a'), isNull);
        expect(await index.getAllKeys(), [10]);
      });
    });

    test('add an existing key fails', () async {
      await openDb((db) {
        db.createObjectStore('s');
      });
      await inTxn(idbModeReadWrite, (store) async {
        await store.add('one', 1);
        try {
          await store.add('two', 1);
          fail('should fail');
        } catch (e) {
          expect(e, isNot(isA<TestFailure>()));
          expect(_isConstraintError(e), isTrue, reason: '$e');
        }
      });
    });

    test('add an existing key fails (array key path)', () async {
      await openDb((db) {
        db.createObjectStore('s', keyPath: ['a', 'b']);
      });
      await inTxn(idbModeReadWrite, (store) async {
        await store.add({'a': 1, 'b': 2, 'v': 'one'});
        try {
          await store.add({'a': 1, 'b': 2, 'v': 'two'});
          fail('should fail');
        } catch (e) {
          expect(e, isNot(isA<TestFailure>()));
          expect(_isConstraintError(e), isTrue, reason: '$e');
        }
      });
    });

    test('string keys never match number keys (autoIncrement)', () async {
      await openDb((db) {
        db.createObjectStore('s', autoIncrement: true);
      });
      await inTxn(idbModeReadWrite, (store) async {
        expect(await store.add('a'), 1);
        expect(await store.add('b'), 2);
        expect(await store.getObject('1'), isNull);
        expect(await store.count('1'), 0);
        // Numbers are before strings in the key order.
        expect(await store.getAllKeys(KeyRange.lowerBound('1')), isEmpty);
        expect(await store.getAllKeys(KeyRange.upperBound('1')), [1, 2]);
      });
    });

    test('index cursor update visits every multiEntry entry', () async {
      await openDb((db) {
        db.createObjectStore('s').createIndex('m', 'v', multiEntry: true);
      });
      await inTxn(idbModeReadWrite, (store) async {
        await store.put({
          'v': ['a', 'b', 'c'],
        }, 0);
      });
      var entries = <String>[];
      await inTxn(idbModeReadWrite, (store) async {
        var completer = Completer<void>();
        store
            .index('m')
            .openCursor(autoAdvance: false)
            .listen(
              (cursor) async {
                entries.add('${cursor.key}:${cursor.primaryKey}');
                if (cursor.key == 'a') {
                  await cursor.update({
                    'v': ['a', 'b', 'c'],
                    'x': 1,
                  });
                }
                cursor.next();
              },
              onDone: completer.complete,
              onError: completer.completeError,
            );
        await completer.future.timeout(const Duration(seconds: 10));
      });
      expect(entries, ['a:0', 'b:0', 'c:0']);
    });

    test('cursor on an array key index bound completes', () async {
      await openDb((db) {
        db.createObjectStore('s').createIndex('ab', ['a', 'b']);
      });
      await inTxn(idbModeReadWrite, (store) async {
        await store.put({'a': 1, 'b': 1}, 1);
      });
      var keys = await inTxn(idbModeReadOnly, (store) async {
        var keys = <Object>[];
        await store
            .index('ab')
            .openCursor(range: KeyRange.lowerBound([1]), autoAdvance: true)
            .listen((cursor) => keys.add(cursor.primaryKey))
            .asFuture<void>()
            .timeout(const Duration(seconds: 10));
        return keys;
      });
      // [1] is before [1, 1] in the key order.
      expect(keys, [1]);
    });

    test('cursor update in a readonly transaction fails', () async {
      await openDb((db) {
        db.createObjectStore('s');
      });
      await inTxn(idbModeReadWrite, (store) => store.put('one', 1));
      Object? error;
      await inTxn(idbModeReadOnly, (store) async {
        var completer = Completer<void>();
        store
            .openCursor(autoAdvance: false)
            .listen(
              (cursor) async {
                try {
                  await cursor.update('two');
                } catch (e) {
                  error = e;
                }
                cursor.next();
              },
              onDone: completer.complete,
              onError: completer.completeError,
            );
        await completer.future.timeout(const Duration(seconds: 10));
      });
      expect(error, isNotNull);
      expect(isTransactionReadOnlyError(error!), isTrue, reason: '$error');
      expect(
        await inTxn(idbModeReadOnly, (store) => store.getObject(1)),
        'one',
      );
    });

    test('cursor update with a different in-line key fails', () async {
      await openDb((db) {
        db.createObjectStore('s', keyPath: 'id');
      });
      await inTxn(idbModeReadWrite, (store) => store.put({'id': 1}));
      Object? error;
      await inTxn(idbModeReadWrite, (store) async {
        var completer = Completer<void>();
        store
            .openCursor(autoAdvance: false)
            .listen(
              (cursor) async {
                try {
                  await cursor.update({'id': 2});
                } catch (e) {
                  error = e;
                }
                cursor.next();
              },
              onDone: completer.complete,
              onError: completer.completeError,
            );
        await completer.future.timeout(const Duration(seconds: 10));
      });
      expect(error, isNotNull);
      expect(error.toString(), contains('DataError'));
      var keys = await inTxn(idbModeReadOnly, (store) => store.getAllKeys());
      expect(keys, [1]);
    });

    test('getAll count 0 is unlimited', () async {
      await openDb((db) {
        db.createObjectStore('s').createIndex('v', 'v');
      });
      await inTxn(idbModeReadWrite, (store) async {
        await store.put({'v': 'a'}, 1);
        await store.put({'v': 'b'}, 2);
        await store.put({'v': 'c'}, 3);
      });
      await inTxn(idbModeReadOnly, (store) async {
        expect(await store.getAll(null, 0), hasLength(3));
        expect(await store.getAllKeys(null, 0), [1, 2, 3]);
        var index = store.index('v');
        expect(await index.getAll(null, 0), hasLength(3));
        expect(await index.getAllKeys(null, 0), [1, 2, 3]);
        // A positive count still limits.
        expect(await store.getAllKeys(null, 2), [1, 2]);
        expect(await index.getAllKeys(null, 2), [1, 2]);
      });
    });

    Future<void> roundTrip(Map<String, Object?> value) async {
      await openDb((db) {
        db.createObjectStore('s');
      });
      await inTxn(idbModeReadWrite, (store) => store.put(value, 1));
      expect(
        await inTxn(idbModeReadOnly, (store) => store.getObject(1)),
        value,
      );
    }

    test('map with a single @ key round trips', () async {
      await roundTrip(<String, Object?>{'@x': 1});
    });

    test(
      'map with a single @ key and a date round trips',
      () async {
        await roundTrip(<String, Object?>{'@x': DateTime.utc(2020)});
      },
      // sembast does not encode the values of a map it escapes (a single key
      // starting with '@', sembast json_encodable_codec.dart
      // _toJsonEncodable), so a jdb storage cannot store the date in it.
      skip: _isSembastJdb(ctx)
          ? 'sembast: the values of an escaped map are not encoded'
          : null,
    );
  });
}
