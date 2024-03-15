library open_test_common;

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  // new
  late String dbName;
  // prepare for test
  Future<String> setupDeleteDb() async {
    dbName = ctx.dbName;
    await idbFactory.deleteDatabase(dbName);
    return dbName;
  }

  group('delete', () {
    test('delete database', () async {
      await setupDeleteDb();
      return idbFactory.deleteDatabase(dbName);
    });
  });

  group('open', () {
    test('no param', () async {
      await setupDeleteDb();
      return idbFactory.open(dbName).then((Database database) {
        expect(database.version, 1);
        database.close();
      });
    });

    test('close then re-open', () async {
      await setupDeleteDb();
      return idbFactory.open(dbName).then((Database database) {
        database.close();
        return idbFactory.open(dbName).then((Database database) {
          database.close();
        });
      });
    });

    /*
    test('no name', () {
      return idbFactory.open(null).then((Database database) {
        fail('should fail');
      }, onError: (e) {});
    }, testOn: '!js');

    test('no name', () {
      return idbFactory.open(null).then((Database database) {
        database.close();
      });
    }, testOn: 'js');
    */

    test('bad param with onUpgradeNeeded', () async {
      await setupDeleteDb();
      void emptyInitializeDatabase(VersionChangeEvent e) {}

      try {
        await idbFactory.open(dbName, onUpgradeNeeded: emptyInitializeDatabase);
        fail('should fail');
      } on ArgumentError catch (e) {
        expect(e.message,
            'version and onUpgradeNeeded must be specified together');
      }
    });

    test('throw in onUpgradeNeeded', () async {
      await setupDeleteDb();

      try {
        await idbFactory.open(dbName, onUpgradeNeeded: (_) {
          throw StateError('My error');
        }, version: 1);
        fail('should fail');
      } on StateError catch (e) {
        expect(e.message, 'My error');
      }
    });

    test('throw late in onUpgradeNeeded', () async {
      await setupDeleteDb();

      try {
        await idbFactory.open(dbName, onUpgradeNeeded: (_) {
          throw StateError('My error');
        }, version: 1);
        fail('should fail');
      } on StateError catch (e) {
        expect(e.message, 'My error');
      }
    });

    test('bad param with version', () async {
      await setupDeleteDb();
      try {
        await idbFactory.open(dbName, version: 1);
        fail('should fail');
      } on ArgumentError catch (e) {
        expect(e.message,
            'version and onUpgradeNeeded must be specified together');
      }
    });

    test('open with version 0', () async {
      await setupDeleteDb();
      var initCalled = false;
      void onUpgradeNeeded(VersionChangeEvent e) {
        // should be called
        initCalled = true;
      }

      try {
        await idbFactory.open(dbName,
            version: 0, onUpgradeNeeded: onUpgradeNeeded);
        fail('should not open');
      } catch (e) {
        // cannot check type here...
        expect(initCalled, isFalse);
      }
    });

    test('default then version 1', () async {
      await setupDeleteDb();
      var database = await idbFactory.open(dbName);
      expect(database.version, 1);
      database.close();

      // devPrint('#1');
      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        // devPrint('#2');
        var initCalled = false;
        void onUpgradeNeeded(VersionChangeEvent e) {
          // should not be called
          // devPrint('previous ${e.oldVersion} new ${e.newVersion}');
          initCalled = true;
        }

        database = await idbFactory.open(dbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);
        expect(initCalled, false);
        database.close();
      }
    });

    test('version 1', () async {
      await setupDeleteDb();
      var initCalled = false;

      void onUpgradeNeeded(VersionChangeEvent e) {
        // should be called
        var onUpgradeOldVersion = e.oldVersion;
        var onUpgradeNewVersion = e.newVersion;
        expect(onUpgradeOldVersion, 0);
        expect(onUpgradeNewVersion, 1);
        initCalled = true;
      }

      var database = await idbFactory.open(dbName,
          version: 1, onUpgradeNeeded: onUpgradeNeeded);

      expect(initCalled, true);
      database.close();
    });

    test('version 1 then 2', () async {
      await setupDeleteDb();
      var initCalled = false;
      late int onUpgradeOldVersion;
      late int onUpgradeNewVersion;
      void onUpgradeNeeded(VersionChangeEvent e) {
        onUpgradeOldVersion = e.oldVersion;
        onUpgradeNewVersion = e.newVersion;
        initCalled = true;
      }

      var database = await idbFactory.open(dbName,
          version: 1, onUpgradeNeeded: onUpgradeNeeded);
      expect(onUpgradeOldVersion, 0);
      expect(onUpgradeNewVersion, 1);
      expect(initCalled, true);
      expect(database.version, 1);
      database.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        var upgradeCalled = false;
        void onUpgradeNeeded(VersionChangeEvent e) {
          // should be called
          onUpgradeOldVersion = e.oldVersion;
          onUpgradeNewVersion = e.newVersion;
          upgradeCalled = true;
        }

        database = await idbFactory.open(dbName,
            version: 2, onUpgradeNeeded: onUpgradeNeeded);

        expect(upgradeCalled, true);
        expect(database.version, 2);
        expect(onUpgradeOldVersion, 1);
        expect(onUpgradeNewVersion, 2);
        database.close();

        database = await idbFactory.open(dbName);
        expect(database.version, 2);
        database.close();
      }
    });

    test('version 2 then downgrade', () async {
      await setupDeleteDb();
      var initCalled = false;
      void onUpgradeNeeded(VersionChangeEvent e) {
        // should not be called
        initCalled = true;
      }

      var database = await idbFactory.open(dbName,
          version: 2, onUpgradeNeeded: onUpgradeNeeded);

      expect(initCalled, true);
      database.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        var downgradeCalled = false;
        void onUpgradeNeeded(VersionChangeEvent e) {
          // should not be be called
          downgradeCalled = true;
        }

        try {
          await idbFactory.open(dbName,
              version: 1, onUpgradeNeeded: onUpgradeNeeded);
          fail('should fail');
        } catch (e) {
          expect(e, isNot(const TypeMatcher<TestFailure>()));
        }
        expect(downgradeCalled, false);
      }
    });

    test('abort', () async {
      var initCalled = false;
      await setupDeleteDb();
      try {
        await idbFactory.open(dbName, version: 2, onUpgradeNeeded: (event) {
          initCalled = true;
          event.transaction.abort();
        });
        fail('should fail');
      } catch (e) {
        expect(e, isNot(const TypeMatcher<TestFailure>()));
      }
      expect(initCalled, true);
      initCalled = false;

      late int initialOldVersion, initialNewVersion;
      var db =
          await idbFactory.open(dbName, version: 3, onUpgradeNeeded: (event) {
        initialOldVersion = event.oldVersion;
        initialNewVersion = event.newVersion;

        initCalled = true;
      });
      expect(initialOldVersion, 0);
      expect(initialNewVersion, 3);
      expect(initCalled, true);
      db.close();
    });

    test('put_read_in_open_transaction', () async {
      await setupDeleteDb();
      late Object putKey;
      late Object? putValue;
      var db = await idbFactory.open(dbName, version: 1,
          onUpgradeNeeded: (event) async {
        var store = event.database.createObjectStore('note');
        await store.put('my_value', 'my_key').then((key) async {
          putKey = key;
          putValue = await store.getObject('my_key');
        });
      });
      expect(putKey, 'my_key');
      expect(putValue, 'my_value');
      try {
        var txn = db.transaction('note', idbModeReadOnly);
        var store = txn.objectStore('note');
        expect(await store.getObject('my_key'), 'my_value');
        await txn.completed;
      } finally {
        db.close();
      }
      db = await idbFactory.open(dbName, version: 2,
          onUpgradeNeeded: (event) async {
        var store = event.transaction.objectStore('note');
        putValue = await store.getObject(putKey);
        await store.put('value2', 'key2');
        store = event.database.createObjectStore('note2');
        await store.put('value3', 'key3');
      });
      expect(putValue, 'my_value');
      try {
        var txn = db.transaction(['note'], idbModeReadOnly);
        var store = txn.objectStore('note');
        expect(await store.getObject('my_key'), 'my_value');
        expect(await store.getObject('key2'), 'value2');
        await txn.completed;

        txn = db.transaction(['note', 'note2'], idbModeReadOnly);
        store = txn.objectStore('note');
        expect(await store.getObject('my_key'), 'my_value');
        expect(await store.getObject('key2'), 'value2');
        store = txn.objectStore('note2');
        expect(await store.getObject('key3'), 'value3');
        await txn.completed;
      } finally {
        db.close();
      }
    });

    //    const String MILESTONE_STORE = 'milestoneStore';
    //    const String NAME_INDEX = 'name_index';
    //
    //    void onUpgradeNeeded(VersionChangeEvent e) {
    //      Database db = (e.target as Request).result;
    //
    //      var objectStore = db.createObjectStore(MILESTONE_STORE, autoIncrement: true);
    //      var index = objectStore.createIndex(NAME_INDEX, 'milestoneName', unique: true);
    //    }
    //
    //
    //    void _initializeTestDatabase(VersionChangeEvent e) {
    //      expect(e.oldVersion, equals(0));
    //      expect(e.newVersion, equals(1));
    //      Database db = (e.target as Request).result;
    //
    //      var objectStore = db.createObjectStore(MILESTONE_STORE, autoIncrement: true);
    //      var index = objectStore.createIndex(NAME_INDEX, 'milestoneName', unique: true);
    //    }
    //    test('open initialize', () {
    //      Function done = expectAsync0(() => null);
    //      idbFactory.deleteDatabase(DB_NAME).then((_) {
    //        idbFactory.open('test', version: 1, onUpgradeNeeded: _initializeTestDatabase).then((Database database) {
    //          database.close();
    //          done();
    //        });
    //      });
    //    });
  });
}
