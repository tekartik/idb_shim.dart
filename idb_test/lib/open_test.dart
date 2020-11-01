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
  String _dbName;
  // prepare for test
  Future<void> _setupDeleteDb() async {
    _dbName = ctx.dbName;
    await idbFactory.deleteDatabase(_dbName);
  }

  group('delete', () {
    test('delete database', () async {
      await _setupDeleteDb();
      return idbFactory.deleteDatabase(_dbName);
    });
  });

  group('open', () {
    test('no param', () async {
      await _setupDeleteDb();
      return idbFactory.open(_dbName).then((Database database) {
        expect(database.version, 1);
        database.close();
      });
    });

    test('close then re-open', () async {
      await _setupDeleteDb();
      return idbFactory.open(_dbName).then((Database database) {
        database.close();
        return idbFactory.open(_dbName).then((Database database) {
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
      await _setupDeleteDb();
      void _emptyInitializeDatabase(VersionChangeEvent e) {}

      return idbFactory
          .open(_dbName, onUpgradeNeeded: _emptyInitializeDatabase)
          .then((_) {
        fail('shoud not open');
      }).catchError((e) {
        expect(e.message,
            'version and onUpgradeNeeded must be specified together');
      }, test: (e) => e is ArgumentError);
    });

    test('bad param with version', () async {
      await _setupDeleteDb();
      return idbFactory.open(_dbName, version: 1).then((_) {}).catchError((e) {
        expect(e.message,
            'version and onUpgradeNeeded must be specified together');
      }, test: (e) => e is ArgumentError);
    });

    test('open with version 0', () async {
      await _setupDeleteDb();
      var initCalled = false;
      void _initializeDatabase(VersionChangeEvent e) {
        // should be called
        initCalled = true;
      }

      return idbFactory
          .open(_dbName, version: 0, onUpgradeNeeded: _initializeDatabase)
          .then((Database database) {
        fail('should not open');
      }, onError: (e) {
        // cannot check type here...
        expect(initCalled, isFalse);
      });
    });

    test('default then version 1', () async {
      await _setupDeleteDb();
      var database = await idbFactory.open(_dbName);
      expect(database.version, 1);
      database.close();

      // devPrint('#1');
      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        // devPrint('#2');
        var initCalled = false;
        void _initializeDatabase(VersionChangeEvent e) {
          // should not be called
          // devPrint('previous ${e.oldVersion} new ${e.newVersion}');
          initCalled = true;
        }

        database = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
        expect(initCalled, false);
        database.close();
      }
    });

    test('version 1', () async {
      await _setupDeleteDb();
      var initCalled = false;
      void _initializeDatabase(VersionChangeEvent e) {
        // should be called
        expect(e.oldVersion, 0);
        expect(e.newVersion, 1);
        initCalled = true;
      }

      return idbFactory
          .open(_dbName, version: 1, onUpgradeNeeded: _initializeDatabase)
          .then((Database database) {
        expect(initCalled, true);
        database.close();
      });
    });

    test('version 1 then 2', () async {
      await _setupDeleteDb();
      var initCalled = false;
      void _initializeDatabase(VersionChangeEvent e) {
        // should be called
        expect(e.oldVersion, 0);
        expect(e.newVersion, 1);
        initCalled = true;
      }

      var database = await idbFactory.open(_dbName,
          version: 1, onUpgradeNeeded: _initializeDatabase);

      expect(initCalled, true);
      expect(database.version, 1);
      database.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        var upgradeCalled = false;
        void _upgradeDatabase(VersionChangeEvent e) {
          // should be called
          expect(e.oldVersion, 1);
          expect(e.newVersion, 2);
          upgradeCalled = true;
        }

        database = await idbFactory.open(_dbName,
            version: 2, onUpgradeNeeded: _upgradeDatabase);

        expect(upgradeCalled, true);
        expect(database.version, 2);
        database.close();

        database = await idbFactory.open(_dbName);
        expect(database.version, 2);
        database.close();
      }
    });

    test('version 2 then downgrade', () async {
      await _setupDeleteDb();
      var initCalled = false;
      void _initializeDatabase(VersionChangeEvent e) {
        // should not be called
        initCalled = true;
      }

      var database = await idbFactory.open(_dbName,
          version: 2, onUpgradeNeeded: _initializeDatabase);

      expect(initCalled, true);
      database.close();

      // not working in memory since not persistent
      if (!ctx.isInMemory) {
        var downgradeCalled = false;
        void _downgradeDatabase(VersionChangeEvent e) {
          // should not be be called
          downgradeCalled = true;
        }

        await idbFactory
            .open(_dbName, version: 1, onUpgradeNeeded: _downgradeDatabase)
            .then((Database database) {
          fail('should fail');
        }, onError: (err, st) {
          // this should fail
          expect(downgradeCalled, false);
        });
      }
    });

    //    const String MILESTONE_STORE = 'milestoneStore';
    //    const String NAME_INDEX = 'name_index';
    //
    //    void _initializeDatabase(VersionChangeEvent e) {
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
