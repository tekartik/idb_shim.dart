library IndexedDB3Test;

import 'idb_test_common.dart';
import 'dart:async';
import 'package:idb_shim/idb_client.dart';

// Read with cursor.
const String DB_NAME = 'Test3';
const String STORE_NAME = 'TEST';
const int VERSION = 1;

Future<Database> createAndOpenDb(IdbFactory idbFactory) {
  return idbFactory.deleteDatabase(DB_NAME).then((_) {
    return idbFactory.open(DB_NAME, version: VERSION, onUpgradeNeeded: (e) {
      var db = e.target.result;
      db.createObjectStore(STORE_NAME);
    });
  });
}

/*
Future<Database> writeItems(Database db) {
  Future<Object> write(index) {
    var transaction = db.transaction(STORE_NAME, 'readwrite');
    transaction.objectStore(STORE_NAME).put('Item $index', index);
    return transaction.completed;
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
  var transaction = db.transaction(STORE_NAME, 'readwrite');

  Future<Object> write(index) {
    return transaction.objectStore(STORE_NAME).put('Item $index', index);
  }

  var future = write(0);
  for (var i = 1; i < 100; ++i) {
    future = future.then((_) => write(i));
  }

  // Chain on the DB so we return it at the end.
  return transaction.completed.then((_) => db);
}

Future<Database> setupDb(IdbFactory idbFactory) {
  return createAndOpenDb(idbFactory).then(writeItems).then((db) {
    return db;
  });
}

Future<Database> readAllViaCursor(Database db) {
  Transaction txn = db.transaction(STORE_NAME, 'readonly');
  ObjectStore objectStore = txn.objectStore(STORE_NAME);
  int itemCount = 0;
  int sumKeys = 0;
  var lastKey = null;

  var cursors = objectStore.openCursor().asBroadcastStream();
  cursors.listen((CursorWithValue cursor) {
    //print(cursor);
    ++itemCount;
    lastKey = cursor.key;
    sumKeys += cursor.key;
    expect(cursor.value, 'Item ${cursor.key}');
    cursor.next();
  });
  cursors.last.then((cursor) {
    expect(lastKey, 99);
    expect(sumKeys, (100 * 99) ~/ 2);
    expect(itemCount, 100);
  });

  return cursors.last.then((_) => db);
}

Future<Database> readAllReversedViaCursor(Database db) {
  Transaction txn = db.transaction(STORE_NAME, 'readonly');
  ObjectStore objectStore = txn.objectStore(STORE_NAME);
  int itemCount = 0;
  int sumKeys = 0;
  var lastKey = null;

  var cursors = objectStore.openCursor(direction: 'prev').asBroadcastStream();
  cursors.listen((cursor) {
    ++itemCount;
    lastKey = cursor.key;
    sumKeys += cursor.key;
    expect(cursor.value, 'Item ${cursor.key}');
    cursor.next();
  });
  cursors.last.then((cursor) {
    expect(lastKey, 0);
    expect(sumKeys, (100 * 99) ~/ 2);
    expect(itemCount, 100);
  });
  return cursors.last.then((_) => db);
}

main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;
  //useHtmlConfiguration();

  // Don't bother with these tests if it's unsupported.
  // Support is tested in indexeddb_1_test
  if (IdbFactory.supported) {
    var db;
    //var oldTimeout;

    group('indexeddb_3', () {
      setUp(() {
        //oldTimeout = unittestConfiguration.timeout;
        //unittestConfiguration.timeout = new Duration(seconds: 30);
        return setupDb(idbFactory).then((result) {
          db = result;
        });
      });

      tearDown(() {
        db.close();
      });

      test('readAll1', () {
        return readAllViaCursor(db);
      });

      test('readAll2', () {
        return readAllReversedViaCursor(db);
      });
    });
  }
}
