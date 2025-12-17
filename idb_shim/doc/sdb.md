# SDB

SDB stands for Simple DB, it provides a dart API on top of indexed_db or sqlite.
The API is similar to sembast but requires some schema configuration.
- Each store must be declared and added once to a database.
- Efficient queries are limited to boundaries and indexes, sembast like filtering is done in memory.
- Data is not preloaded in memory

It provides an efficient simple database both on IO (when using sqflite) and web.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
    idb_shim:
```

On IO the recommended cross process safe implementation is `idb_sqflite`:

```yaml
dependencies:
    idb_sqflite:
```

## Usage

### Factory

First find the proper factory, this works on all
platform (Web, mobile, desktop).

```dart
import 'package:idb_shim/sdb.dart';

late SdbFactory factory;
if (kSdbDartIsWeb) {
  // Web factory
  factory = sdbFactoryWeb;
} else {
  // Io factory, prefer using sdbFactorySqflite though.
  factory = sdbFactoryIo;
}
```

Prefer using sqflite on IO:

If you have `sqflite` dependency (flutter only):

```dart
import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late SdbFactory factory;
if (kSdbDartIsWeb) {
  // Uses indexed db on the web
  factory = sdbFactoryWeb;
} else {
  if (Platform.isWindows || Platform.isLinux) {
    // Use sqflite_common_ffi on Windows and Linux
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Uses sqflite on desktop and mobile
  factory = sdbFactorySqflite;
}
```

If you only uses `sqflite_common_ffi` (dart and flutter):

```dart
import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late SdbFactory factory;
if (kSdbDartIsWeb) {
  // Uses indexed db on the web
  factory = sdbFactoryWeb;
} else {
  // Use sqflite_common_ffi on mobile and desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  // Uses sqflite on desktop and mobile
  factory = sdbFactorySqflite;
}
```

### Open a database

#### The schema

You must first define a schema for each store/table, defining
the key type and the value type.
Good options is to use `int` as a key and `SdbModel` (which is a typedef for `Map<String, Object?>`) as a value.

```dart
// Our book store/table
var bookStore = SdbStoreRef<int, SdbModel>('book');
```

#### The database

On the web it represents an indexed_db database, on IO it represents a sqlite or sembast database.
You might want to use `path_provider` to find the best location.

#### Opening

Similar to indexed_db and sqlite, you must specify a version and an optional callback
to modify the schema
```dart
// Open the database
var db = await factory.openDatabase('book.db', version: 1, onVersionChange: (event) {
  var db = event.db;
  var oldVersion = event.oldVersion;
  if (oldVersion < 1) {
    // Create the book store
    db.createStore(bookStore);
  }
});

// ...access the database.
    
// Close the database
await db.close();
```

Instead of `onVersionChange`, you can also specify a schema that will handle the migration for you, as long
as you update the version number when the schema changes.

```dart
class SchoolDb {
  final schoolStore = SdbStoreRef<String, SdbModel>('school');
  final studentStore = SdbStoreRef<int, SdbModel>('student');

  /// Index on studentStore for field 'schoolId'
  late final studentSchoolIndex = studentStore.index<String>(
    'school',
  ); // On field 'schoolId'
  late final schoolDbSchema = SdbDatabaseSchema(
    stores: [
      schoolStore.schema(),
      studentStore.schema(
        autoIncrement: true,
        indexes: [studentSchoolIndex.schema(keyPath: 'schoolId')],
      ),
    ],
  );
  
  Future<SdbDatabase> open(SdbFactory factory, String dbName) async {
    return factory.openDatabase(
      dbName,
      version: 1,
      schema: schoolDbSchema,
    );
  }
}
```

### Adding a record

```dart
// Add a record and get its key (int here)
var key = await bookStore.add(db, {'title': 'Book 1'});
```

### Reading a record

```dart
/// Get the record by key
var record = bookStore.record(key);
var snapshot = await record.get(db);
print(snapshot?.key); // 1
print(snapshot?.value); // {'title': 'Book 1'}
```

The API is similar to sembast but:
- no listener
- simple query (using boundaries)
- Index on up to 4 fields
- Sembast like filtering is done in memory and requires loading the record first

### Transaction

Similar to indexed db, you declare the stores on which the transaction occurs and the mode (read or write).

Note that since indexed_db does not allow for a transaction to be opened forever you need to keep your transaction
for doing only doing synchronous operations or async operations only on the database (i.e. don't fetch data or any other
async operation that does not involve reading or writing to the database).

```dart
await db.inStoreTransaction(bookStore, SdbTransactionMode.readWrite,
    (txn) async {
  await bookStore
      .add(txn, {'title': 'Le petit prince', 'serial': 'serial0001'});
  await bookStore.add(txn, {'title': 'Hamlet', 'serial': 'serial0002'});
  await bookStore
      .add(txn, {'title': 'Harry Potter', 'serial': 'serial0003'});
});
```

Recommendations:
- Don't catch exceptions inside the transaction callback, let them propagate to abort the transaction.
  Any exception will abort the transaction so catching them will likely lead to unexpected results.
- Keep the transaction callback as short as possible
- Don't do any async operation that does not involve reading or writing to the database inside the transaction

### Creating index

```dart
// Our book store/table
var bookStore = SdbStoreRef<int, SdbModel>('book');
// Index on 'serial' field
var bookSerialIndex = bookStore.index<String>('serial');
```

Index must be created during open

```dart
db = await factory.openDatabase(path, version: 2, onVersionChange: (event) {
  var db = event.db;
  var oldVersion = event.oldVersion;
  if (oldVersion < 1) {
    // Create the book store
    var openStoreRef = db.createStore(bookStore);
    openStoreRef.createIndex(bookSerialIndex, 'serial');
  } else {
    var openStoreRef = db.objectStore(bookStore);
    openStoreRef.createIndex(bookSerialIndex, 'serial');
  }
});
```

You can then read a record by an index value:

```dart
// Read by serial
var book = await bookSerialIndex.record('serial0002').get(db);
expect(book!.value['title'], 'Hamlet');
```

Or find records by boundaries:

```dart
// Find >=serial0001 and <serial0003 (serial0003 excluded)
var books = await bookSerialIndex.findRecords(db,
    boundaries: SdbBoundaries.values('serial0001', 'serial0003'));
expect(books[0].value['title'], 'Le petit prince');
expect(books[1].value['title'], 'Hamlet');
expect(books, hasLength(2));
```

## Generic filters

Generic filters (same as sembast) can be used to filter records by any field.
However, they are less efficient than using indexes since records are loaded in memory when checking
filters. Best is to filter by boundaries/indexes as much as possible.

```dart
// Search by generic filters (matching boundaries record are all loaded in memory)
var indexBooksFiltered = await bookSerialIndex.findRecords(
  db,
  filter: SdbFilter.equals('title', 'Hamlet'),
);
print(indexBooksFiltered);
// [Record(book, 3, {title: Hamlet, serial: serial0002}]
expect(indexBooksFiltered[0].key, keyHamlet);
expect(indexBooksFiltered[0].indexKey, 'serial0002');
expect(indexBooksFiltered, hasLength(1));
```
