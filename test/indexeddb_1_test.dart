// https://dart.googlecode.com/svn/branches/bleeding_edge/dart/tests/html/indexeddb_1_test.dart
// replace _idbFactory with _idbFactory
library IndexedDB1Test;

//TEKARTIK_IDB_REMOVED import 'package:unittest/html_individual_config.dart';
import 'dart:async';
//TEKARTIK_IDB_REMOVED import 'dart:html' as html;
//TEKARTIK_IDB_REMOVED import 'dart:indexed_db' as idb;
import 'package:idb_shim/idb_client.dart' as idb;

// so that this can be run directly
import 'idb_test_common.dart';

const String STORE_NAME = 'TEST';
const int VERSION = 1;

var databaseNameIndex = 0;
String nextDatabaseName() {
  return 'Test1_${databaseNameIndex++}';
}

Future testUpgrade(idb.IdbFactory idbFactory) {
  var dbName = nextDatabaseName();
  var upgraded = false;

  // Delete any existing DBs.
  //TEKARTIK_IDB_REMOVED return _idbFactory.deleteDatabase(dbName).then((_) {
  return idbFactory.deleteDatabase(dbName).then((_) {
    //TEKARTIK_IDB_REMOVED return _idbFactory.open(dbName, version: 1,
    return idbFactory.open(dbName, version: 1, onUpgradeNeeded: (e) {});
  }).then((db) {
    db.close();
  }).then((_) {
    //TEKARTIK_IDB_REMOVED return _idbFactory.open(dbName, version: 2,
    return idbFactory.open(dbName, version: 2, onUpgradeNeeded: (e) {
      expect(e.oldVersion, 1);
      expect(e.newVersion, 2);
      upgraded = true;
    });
  }).then((_) {
    expect(upgraded, isTrue);
  });
}

typedef dynamic BodyFunc();

typedef BodyFunc TestFunc(idb.IdbFactory idbFactory, key, value, matcher,
    [String dbName, String storeName, int version, bool stringifyResult]);

BodyFunc testReadWrite(idb.IdbFactory idbFactory, key, value, matcher,
        [String dbName,
        String storeName = STORE_NAME,
        int version = VERSION,
        bool stringifyResult = false]) =>
    () {
      if (dbName == null) {
        dbName = nextDatabaseName();
      }
      createObjectStore(idb.VersionChangeEvent e) {
        var store = e.database.createObjectStore(storeName);
        expect(store, isNotNull);
      }

      var db;
      //TEKARTIK_IDB_REMOVED return _idbFactory.deleteDatabase(dbName).then((_) {
      return idbFactory.deleteDatabase(dbName).then((_) {
        //TEKARTIK_IDB_REMOVED return _idbFactory.open(dbName, version: version,
        return idbFactory.open(dbName,
            version: version, onUpgradeNeeded: createObjectStore);
      }).then((result) {
        db = result;
        var transaction = db.transactionList([storeName], 'readwrite');
        transaction.objectStore(storeName).put(value, key);
        return transaction.completed;
      }).then((_) {
        var transaction = db.transaction(storeName, 'readonly');
        return transaction.objectStore(storeName).getObject(key);
      }).then((object) {
        db.close();
        if (stringifyResult) {
          // Stringify the numbers to verify that we're correctly returning ints
          // as ints vs doubles.
          expect(object.toString(), matcher);
        } else {
          expect(object, matcher);
        }
      }).whenComplete(() {
        if (db != null) {
          db.close();
        }
        return idbFactory.deleteDatabase(dbName);
      });
    };

BodyFunc testReadWriteTyped(idb.IdbFactory idbFactory, key, value, matcher,
        [String dbName,
        String storeName = STORE_NAME,
        int version = VERSION,
        bool stringifyResult = false]) =>
    () {
      if (dbName == null) {
        dbName = nextDatabaseName();
      }
      void createObjectStore(idb.VersionChangeEvent e) {
        var store = e.database.createObjectStore(storeName);
        expect(store, isNotNull);
      }

      idb.Database db;
      // Delete any existing DBs.
      return idbFactory.deleteDatabase(dbName).then((_) {
        return idbFactory.open(dbName,
            version: version, onUpgradeNeeded: createObjectStore);
      }).then((idb.Database result) {
        db = result;
        idb.Transaction transaction =
            db.transactionList([storeName], 'readwrite');
        transaction.objectStore(storeName).put(value, key);

        return transaction.completed;
      }).then((idb.Database result) {
        idb.Transaction transaction = db.transaction(storeName, 'readonly');
        return transaction.objectStore(storeName).getObject(key);
      }).then((object) {
        db.close();
        if (stringifyResult) {
          // Stringify the numbers to verify that we're correctly returning ints
          // as ints vs doubles.
          expect(object.toString(), matcher);
        } else {
          expect(object, matcher);
        }
      }).whenComplete(() {
        if (db != null) {
          db.close();
        }
        return idbFactory.deleteDatabase(dbName);
      });
    };

void testTypes(TestFunc testFunction, idb.IdbFactory idbFactory) {
  test('String', testFunction(idbFactory, 123, 'Hoot!', equals('Hoot!')));
  test('int', testFunction(idbFactory, 123, 12345, equals(12345)));
  test('List', testFunction(idbFactory, 123, [1, 2, 3], equals([1, 2, 3])));
  test('List 2', testFunction(idbFactory, 123, [2, 3, 4], equals([2, 3, 4])));
  test('bool',
      testFunction(idbFactory, 123, [true, false], equals([true, false])));
  test(
      'largeInt',
      testFunction(idbFactory, 123, 1371854424211, equals("1371854424211"),
          null, STORE_NAME, VERSION, true));
  //TEKARTIK_IDB_REMOVED
  test(
      'largeDoubleConvertedToInt',
      testFunction(idbFactory, 123, 1371854424211.0, equals("1371854424211"),
          null, STORE_NAME, VERSION, true),
      skip: true);
  test(
      'largeIntInMap',
      testFunction(idbFactory, 123, {'time': 4503599627370492},
          equals("{time: 4503599627370492}"), null, STORE_NAME, VERSION, true));
  var now = new DateTime.now();
  //TEKARTIK_IDB_REMOVED
  test(
      'DateTime',
      testFunction(
          idbFactory,
          123,
          now,
          predicate((date) =>
              date.millisecondsSinceEpoch == now.millisecondsSinceEpoch)),
      skip: true);
}

//TEKARTIK_IDB_REMOVED main() {
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  idb.IdbFactory idbFactory = ctx.factory;
  //TEKARTIK_IDB_REMOVED useHtmlIndividualConfiguration();

  // Test that indexed_db is properly flagged as supported or not.
  // Note that the rest of the indexed_db tests assume that this has been
  // checked.
  group('supported', () {
    test('supported', () {
      expect(idb.IdbFactory.supported, true);
    });
  }, skip: true);

  group('supportsDatabaseNames', () {
    test('supported', () {
      expect(idbFactory.supportsDatabaseNames, isTrue);
    });
  }, skip: true);

  group('functional', () {
    test('throws when unsupported', () async {
      bool failed = false;

      try {
        var db = idbFactory;
        await db.open('random_db');
      } catch (_) {
        failed = true;
      }
      expect(failed, !idb.IdbFactory.supported);
    });

    // Don't bother with these tests if it's unsupported.
    if (idb.IdbFactory.supported) {
      test('upgrade', () => testUpgrade(idbFactory));
      // temp skip
      group('dynamic', () {
        testTypes(testReadWrite, idbFactory);
      }, skip: true);

      group('typed', () {
        // crashes on Safari
        if (!ctx.isIdbSafari) {
          testTypes(testReadWriteTyped, idbFactory);
        }
      });
    }
  });
}
