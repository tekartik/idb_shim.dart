library idb_shim.test.indexeddb_4_test;

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';
// so that this can be run directly

// Test for KeyRange and Cursor.
const String _dbName = 'Test4';
const String _storeName = 'TEST';
const int _version = 1;

Future<Database> createAndOpenDb(IdbFactory idbFactory) {
  return idbFactory.deleteDatabase(_dbName).then((_) {
    return idbFactory.open(_dbName, version: _version, onUpgradeNeeded: (e) {
      var db = e.database;
      db.createObjectStore(_storeName);
    });
  });
}

/*
Future<Database> writeItems(Database db) {
  Future<Object> write(index) {
    var transaction = db.transaction(STORE_NAME, 'readwrite');
    return transaction.objectStore(STORE_NAME).put({
      'content': 'Item $index'
    }, index);
  }

  var future = write(0);
  for (var i = 1; i < 100; ++i) {
    future = future.then((_) => write(i));
  }

  // Chain on the DB so we return it at the end.
  return future.then((_) => db);
}
*/
Future<Database> writeItems(Database db) {
  var transaction = db.transaction(_storeName, 'readwrite');

  Future<Object?> write(index) {
    return transaction
        .objectStore(_storeName)
        .put({'content': 'Item $index'}, index);
  }

  var future = write(0);
  for (var i = 1; i < 100; ++i) {
    future = future.then((_) => write(i));
  }

  // Chain on the DB so we return it at the end.
  return transaction.completed.then((_) => db);
}

Future<Database> setupDb(IdbFactory idbFactory) {
  return createAndOpenDb(idbFactory).then(writeItems);
}

Future testRange(Database db, range, int? expectedFirst, int? expectedLast) {
  //var done = expectAsync0(() {});

  final txn = db.transaction(_storeName, 'readonly');
  final objectStore = txn.objectStore(_storeName);
  var cursors = objectStore
      .openCursor(range: range as KeyRange, autoAdvance: true)
      .asBroadcastStream();

  int? lastKey;
  cursors.listen((cursor) {
    lastKey = cursor.key as int;
    var value = cursor.value as Map;
    expect(value['content'], 'Item ${cursor.key}');
  });

  if (expectedFirst != null) {
    cursors.first.then((cursor) {
      expect(cursor.key, expectedFirst);
    });
  }
  if (expectedLast != null) {
    cursors.last.then((cursor) {
      expect(lastKey, expectedLast);
    });
  }

  return cursors.length.then((length) {
    if (expectedFirst == null) {
      expect(length, isZero);
    } else {
      expect(length, expectedLast! - expectedFirst + 1);
    }
    return txn.completed;
  });
}

void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;
  //useHtmlConfiguration();

  // Don't bother with these tests if it's unsupported.
  // Support is tested in indexeddb_1_test
  if (IdbFactory.supported) {
    late Database db;
    setUp(() {
      return setupDb(idbFactory!).then((result) {
        db = result;
      });
    });
    tearDown(() {
      db.close();
    });
    test('only1', () => testRange(db, KeyRange.only(55), 55, 55));
    test('only2', () => testRange(db, KeyRange.only(100), null, null));
    test('only3', () => testRange(db, KeyRange.only(-1), null, null));

    test('lower1', () => testRange(db, KeyRange.lowerBound(40), 40, 99));
    // OPTIONALS lower2() => testRange(db, new KeyRange.lowerBound(40, open: true), 41, 99);
    test('lower2', () => testRange(db, KeyRange.lowerBound(40, true), 41, 99));
    // OPTIONALS lower3() => testRange(db, new KeyRange.lowerBound(40, open: false), 40, 99);
    test('lower3', () => testRange(db, KeyRange.lowerBound(40, false), 40, 99));

    test('upper1', () => testRange(db, KeyRange.upperBound(40), 0, 40));
    // OPTIONALS upper2() => testRange(db, new KeyRange.upperBound(40, open: true), 0, 39);
    test('upper2', () => testRange(db, KeyRange.upperBound(40, true), 0, 39));
    // upper3() => testRange(db, new KeyRange.upperBound(40, open: false), 0, 40);
    test('upper3', () => testRange(db, KeyRange.upperBound(40, false), 0, 40));

    test('bound1', () => testRange(db, KeyRange.bound(20, 30), 20, 30));

    test('bound2', () => testRange(db, KeyRange.bound(-100, 200), 0, 99));

    /*
    bound3() => // OPTIONALS testRange(db, new KeyRange.bound(20, 30, upperOpen: true),
    testRange(db, new KeyRange.bound(20, 30, false, true), 20, 29);

    bound4() => // OPTIONALS testRange(db, new KeyRange.bound(20, 30, lowerOpen: true),
    testRange(db, new KeyRange.bound(20, 30, true), 21, 30);

    bound5() => // OPTIONALS testRange(db, new KeyRange.bound(20, 30, lowerOpen: true, upperOpen: true),
    testRange(db, new KeyRange.bound(20, 30, true, true), 21, 29);
   
     */
  }
}
