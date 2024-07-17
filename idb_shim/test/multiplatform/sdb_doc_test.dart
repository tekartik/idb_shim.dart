// ignore_for_file: avoid_print

import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_shim/sdb/sdb.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  IdbFactoryLogger.debugMaxLogCount = 100;
  simpleDbDocTest();
}

var testStore = SdbStoreRef<int, SdbModel>('test');
var testIndex = testStore.index<int>('myindex');
var testStore2 = SdbStoreRef<String, SdbModel>('test2');

const kIsWeb = kSdbDartIsWeb;
void simpleDbDocTest() {
  test('init factory', () async {
    late SdbFactory factory;
    if (kIsWeb) {
      // Web factory
      factory = sdbFactoryWeb;
    } else {
      // Io factory, prefer using sdbFactorySqflite though.
      factory = sdbFactoryIo;
    }

    var bookStore = SdbStoreRef<int, SdbModel>('book');

    var path = 'book.db';
    path = join('.dart_tool', 'idb_shim_test', 'doc', path);
    // Open the database
    var db =
        await factory.openDatabase(path, version: 1, onVersionChange: (event) {
      var db = event.db;
      var oldVersion = event.oldVersion;
      if (oldVersion < 1) {
        // Create the book store
        db.createStore(bookStore);
      }
    });
    // ...access the database.
    // Add a record and get its key (int here)
    var key = await bookStore.add(db, {'title': 'Book 1'});

    /// Get the record by key
    var record = bookStore.record(key);
    var snapshot = await record.get(db);
    print(snapshot?.key); // 1
    print(snapshot?.value); // {'title': 'Book 1'}

    // Close the database
    await db.close();
  });
}
