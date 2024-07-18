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
  test('doc example', () async {
    late SdbFactory factory;
    if (kIsWeb) {
      // Web factory
      factory = sdbFactoryWeb;
    } else {
      // Io factory, prefer using sdbFactorySqflite though.
      factory = sdbFactoryIo;
    }

    // Our book store/table
    var bookStore = SdbStoreRef<int, SdbModel>('book');
    // Index on 'serial' field
    var bookSerialIndex = bookStore.index<String>('serial');

    var path = 'book.db';
    path = join('.dart_tool', 'idb_shim_test', 'doc', path);

    await factory.deleteDatabase(path);
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

    await db.close();

    db = await factory.openDatabase(path, version: 2, onVersionChange: (event) {
      var db = event.db;
      var oldVersion = event.oldVersion;
      if (oldVersion < 1) {
        // Create the book store
        var openStoreRef = db.createStore(bookStore);
        openStoreRef.createIndex(bookSerialIndex, 'serial');
      } else if (oldVersion < 2) {
        var openStoreRef = db.objectStore(bookStore);
        openStoreRef.createIndex(bookSerialIndex, 'serial');
      }
    });
    late int keyLePetitPrince;
    late int keyHamlet;
    await db.inStoreTransaction(bookStore, SdbTransactionMode.readWrite,
        (txn) async {
      keyLePetitPrince = await bookStore
          .add(txn, {'title': 'Le petit prince', 'serial': 'serial0001'});
      keyHamlet =
          await bookStore.add(txn, {'title': 'Hamlet', 'serial': 'serial0002'});
      await bookStore
          .add(txn, {'title': 'Harry Potter', 'serial': 'serial0003'});
    });

    // Read by key boundaries
    var books1 =
        await bookStore.findRecords(db, boundaries: SdbBoundaries.values(1, 3));
    print(books1);
    expect(books1, hasLength(2));
    // Read by serial
    var book = await bookSerialIndex.record('serial0002').get(db);
    expect(book!.value['title'], 'Hamlet');

    // Find >=serial0001 and <serial0003
    var books = await bookSerialIndex.findRecords(db,
        boundaries: SdbBoundaries.values('serial0001', 'serial0003'));
    print(books);
    expect(books[0].value['title'], 'Le petit prince');
    expect(books[1].value['title'], 'Hamlet');
    expect(books, hasLength(2));

    books = await bookSerialIndex.findRecords(db,
        boundaries: SdbBoundaries.values('serial0001', 'serial0003'),
        offset: 1);

    expect(books[0].value['title'], 'Hamlet');
    expect(books, hasLength(1));
    books = await bookSerialIndex.findRecords(db,
        boundaries: SdbBoundaries.values('serial0001', 'serial0003'), limit: 1);

    expect(books[0].key, keyLePetitPrince);
    expect(books, hasLength(1));

    var bookKeys = await bookSerialIndex.findRecordKeys(db,
        boundaries: SdbBoundaries.values('serial0001', 'serial0003'));
    print(bookKeys);
    expect(bookKeys.map((item) => item.key), [keyLePetitPrince, keyHamlet]);
    expect(bookKeys[0].key, keyLePetitPrince);
    expect(bookKeys[0].indexKey, 'serial0001');
    expect(bookKeys, hasLength(2));

    // Close the database
    await db.close();
    // Our pet store/table
    var petStore = SdbStoreRef<int, SdbModel>('pet');
    // Index on 'type' field
    var petTypeIdIndex = petStore.index2<String, int>('type_id');

    db = await factory.openDatabase(path, version: 3, onVersionChange: (event) {
      var db = event.db;
      var oldVersion = event.oldVersion;
      if (oldVersion < 1) {
        // Create the book store
        var openStoreRef = db.createStore(bookStore);
        openStoreRef.createIndex(bookSerialIndex, 'serial');
      } else if (oldVersion < 2) {
        var openStoreRef = db.objectStore(bookStore);
        openStoreRef.createIndex(bookSerialIndex, 'serial');
      }
      if (oldVersion < 3) {
        var openStoreRef =
            db.createStore(petStore, keyPath: 'id', autoIncrement: true);
        openStoreRef.createIndex2(petTypeIdIndex, 'type', 'id');
      }
    });

    late int keyCatAlbert;
    late int keyCatHarriet;
    late int keyDogBeethoven;
    await db.inStoreTransaction(petStore, SdbTransactionMode.readWrite,
        (txn) async {
      keyCatAlbert = await petStore.add(txn, {'type': 'cat', 'name': 'Albert'});
      keyDogBeethoven =
          await petStore.add(txn, {'type': 'dog', 'name': 'Beethoven'});
      keyCatHarriet =
          await petStore.add(txn, {'type': 'cat', 'name': 'Harriet'});
    });
    print(keyCatAlbert);
    print(await petStore.record(keyCatAlbert).get(db));

    var pet = (await petTypeIdIndex.record(('cat', keyCatHarriet)).get(db))!;
    expect(pet.indexKey.$1, 'cat');
    expect(pet.value['name'], 'Harriet');

    var pets = await petTypeIdIndex.findRecords(db);
    expect(pets.map((item) => item.key),
        [keyCatAlbert, keyCatHarriet, keyDogBeethoven]);
    var first = pets.first;
    expect(first.key, keyCatAlbert);
    expect(first.indexKey.$1, 'cat');
    expect(first.indexKey.$2, keyCatAlbert);

    // Close the database
    await db.close();
  });
}
