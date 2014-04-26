library open_test_common;

import 'package:unittest/unittest.dart';
import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

void testMain(IdbFactory idbFactory) {

  group('delete', () {



    test('delete database', () {
      return idbFactory.deleteDatabase(DB_NAME);
    });
  });

  group('open', () {

    setUp(() {
      return idbFactory.deleteDatabase(DB_NAME);
    });

    test('no param', () {
      return idbFactory.open(DB_NAME).then((Database database) {
        expect(database.version, 1);
        database.close();
      });
    });

    test('close then re-open', () {
      return idbFactory.open(DB_NAME).then((Database database) {
        database.close();
        return idbFactory.open(DB_NAME).then((Database database) {
          database.close();
        });
      });
    });

    test('no name', () {
      return idbFactory.open(null).then((Database database) {
        fail("should fail");
      }, onError: (e) {
      });
    });


    test('bad param with onUpgradeNeeded', () {
      void _emptyInitializeDatabase(VersionChangeEvent e) {
      }

      return idbFactory.open(DB_NAME, onUpgradeNeeded: _emptyInitializeDatabase).then((_) {
        fail("shoud not open");
      }).catchError((e) {
        expect(e.message, "version and onUpgradeNeeded must be specified together");
      }, test: (e) => e is ArgumentError);
    });

    test('bad param with version', () {
      return idbFactory.open(DB_NAME, version: 1).then((_) {

      }).catchError((e) {
        expect(e.message, "version and onUpgradeNeeded must be specified together");
      }, test: (e) => e is ArgumentError);
    });

    test('open with version 0', () {
      bool initCalled = false;
      void _initializeDatabase(VersionChangeEvent e) {
        // should be called
        initCalled = true;
      }
      return idbFactory.open(DB_NAME, version: 0, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        fail("should not open");
      }, onError: (e) {
        // cannot check type here...
      });
    });

    test('default then version 1', () {
      return idbFactory.open(DB_NAME).then((Database database) {
        expect(database.version, 1);
        database.close();

        bool initCalled = false;
        void _initializeDatabase(VersionChangeEvent e) {
          // should not be called
          initCalled = true;
        }
        return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
          expect(initCalled, false);
          database.close();
        });
      });
    });

    test('version 1', () {
      bool initCalled = false;
      void _initializeDatabase(VersionChangeEvent e) {
        // should be called
        expect(e.oldVersion, 0);
        expect(e.newVersion, 1);
        initCalled = true;
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        expect(initCalled, true);
        database.close();
      });
    });

    test('version 1 then 2', () {
      bool initCalled = false;
      void _initializeDatabase(VersionChangeEvent e) {
        // should be called
        expect(e.oldVersion, 0);
        expect(e.newVersion, 1);
        initCalled = true;
      }
      return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        expect(initCalled, true);
        database.close();

        bool upgradeCalled = false;
        void _upgradeDatabase(VersionChangeEvent e) {
          // should be called
          expect(e.oldVersion, 1);
          expect(e.newVersion, 2);
          upgradeCalled = true;
        }
        return idbFactory.open(DB_NAME, version: 2, onUpgradeNeeded: _upgradeDatabase).then((Database database) {
          expect(upgradeCalled, true);
          database.close();
        });
      });
    });



    test('version 2 then downgrade', () {
      bool initCalled = false;
      void _initializeDatabase(VersionChangeEvent e) {
        // should not be called
        initCalled = true;
      }
      return idbFactory.open(DB_NAME, version: 2, onUpgradeNeeded: _initializeDatabase).then((Database database) {
        expect(initCalled, true);
        database.close();

        bool downgradeCalled = false;
        void _downgradeDatabase(VersionChangeEvent e) {
          // should not be be called
          downgradeCalled = true;
        }
        return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _downgradeDatabase).then((Database database) {
          fail("should fail");
        }, onError: (err, st) {
          // this should fail
          expect(downgradeCalled, false);
        });
      });
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
