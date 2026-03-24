# SDB - Simple Database

SDB (Simple DB) is a lightweight database abstraction layer for Dart that provides a unified API over IndexedDB (for web) and SQLite (for mobile and desktop). It is designed to be a simple, efficient, and cross-platform solution for data persistence.

The API is inspired by `sembast` but with a stronger emphasis on schema definition and type safety. Key features include:

- **Schema-First:** You must define your database schema, including stores and indexes, before using it. This ensures data consistency and helps prevent common errors.
- **Type-Safe:** The API is designed to be type-safe, allowing you to specify the key and value types for your stores.
- **Cross-Platform:** SDB works seamlessly on the web, mobile (iOS, Android), and desktop (Windows, Linux, macOS).
- **Efficient Queries:** Supports efficient queries using key ranges (boundaries) and indexes. In-memory filtering is also available for more complex queries.
- **Pay-as-you-go:** Data is not preloaded into memory, making it efficient for large datasets.

This document provides a comprehensive guide to using SDB in your Dart and Flutter applications.

## Installation

To get started with SDB, add the `idb_shim` package to your `pubspec.yaml` file:

```yaml
dependencies:
  idb_shim:
```

For mobile and desktop applications, it is highly recommended to use the `idb_sqflite` implementation, which provides a more robust and performant solution using SQLite. To use it, add the `idb_sqflite` package to your `pubspec.yaml`:

```yaml
dependencies:
  idb_sqflite:
```

## Core Concepts

Before diving into the code, let's understand the core concepts of SDB.

### Factory

The `SdbFactory` is the entry point for creating and managing databases. Different factories are provided for different platforms:

- `sdbFactoryWeb`: For web applications, using IndexedDB.
- `sdbFactoryIo`: For mobile and desktop applications, using a simple file-based storage (not recommended for production).
- `sdbFactorySqflite`: For mobile and desktop applications, using SQLite (recommended).

### Database

An `SdbDatabase` represents a single database, which is a collection of stores. Each database has a name and a version.

### Store

An `SdbStore` is a container for your data, similar to a table in a relational database. Each store has a name and holds records, which are key-value pairs.

### Record

An `SdbRecord` represents a single entry in a store. It consists of a unique key and a value. The key is used to identify the record, and the value holds the actual data.

### Schema

The `SdbDatabaseSchema` defines the structure of your database, including the stores and their indexes. The schema is used to create and migrate the database.

## Usage

Now that you understand the core concepts, let's see how to use SDB in practice.

### Choosing a Factory

The first step is to choose the appropriate factory for your platform. Here's how you can do it:

```dart
import 'package:idb_shim/sdb.dart';
import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;

late SdbFactory factory;

if (kSdbDartIsWeb) {
  // Use IndexedDB on the web
  factory = sdbFactoryWeb;
} else {
  // Use sqflite on mobile and desktop
  if (Platform.isWindows || Platform.isLinux) {
    // Use sqflite_common_ffi on Windows and Linux
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  factory = sdbFactorySqflite;
}
```

### Defining the Schema

Next, you need to define the schema for your database. This involves creating store references and defining their properties.

A good practice is to use an `int` as the key and `SdbModel` (a type alias for `Map<String, Object?>`) as the value.

```dart
// Define a store for books with an integer key and a map value.
var bookStore = SdbStoreRef<int, SdbModel>('books');
```

### Opening a Database

To open a database, you need to provide a name, a version, and an `onVersionChange` callback to create or migrate the schema.

```dart
// Open the database
var db = await factory.openDatabase('my_database.db', version: 1,
    onVersionChange: (event) {
  var db = event.db;
  if (event.oldVersion < 1) {
    // Create the 'books' store if it doesn't exist.
    db.createStore(bookStore);
  }
});

// ... use the database ...

// Close the database when you're done.
await db.close();
```

Alternatively, you can provide an `SdbDatabaseSchema` object, which will handle the schema creation and migration for you automatically.

```dart
class MyAppDatabase {
  final schoolStore = SdbStoreRef<String, SdbModel>('schools');
  final studentStore = SdbStoreRef<int, SdbModel>('students');

  late final studentSchoolIndex = studentStore.index<String>('school_id');

  late final schema = SdbDatabaseSchema(
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
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: schema,
      ),
    );
  }
}
```

### Adding and Reading Data

Once the database is open, you can add, read, update, and delete data.

#### Adding a Record

To add a new record to a store, use the `add` method.

```dart
// Add a new book and get its auto-generated key.
var key = await bookStore.add(db, {'title': 'The Hitchhiker\'s Guide to the Galaxy'});
```

#### Reading a Record

To read a record, create a `SdbRecordRef` and use the `get` method.

```dart
var recordRef = bookStore.record(key);
var snapshot = await recordRef.get(db);

print(snapshot?.key);   // The record's key
print(snapshot?.value); // The record's data: {'title': 'The Hitchhiker\'s Guide to the Galaxy'}
```

### Tracking record changes.

You can track changes on a single record (current isolate or tab only)

```dart
var recordRef = bookStore.record(key);
var subscription = recordRef.onSnapshot(db).listen((snapshot) {
   print(snapshot?.key);   // The record's key
   print(snapshot?.value); // The record's data: {'title': 'The Hitchhiker\'s Guide to the Galaxy'}
});
...
subscription.cancel();
```

You can also track change on a store (current isolate or tab only)

```dart
var subscription = bookStore.onSnapshots(db).listen((snapshots) {
  for (var snapshot in snapshots) {
    print(snapshot.key);   // The record's key
    print(snapshot.value); // The record's data
  }
});
```

Similarly, you can track changes on an index record or query.

### Using Transactions

All database operations in SDB are performed within a transaction. This ensures data consistency and atomicity.

```dart
await db.inStoreTransaction(bookStore, SdbTransactionMode.readWrite, (txn) async {
  await bookStore.add(txn, {'title': 'The Restaurant at the End of the Universe'});
  await bookStore.add(txn, {'title': 'Life, the Universe and Everything'});
});
```

**Important considerations for transactions:**

- **Keep them short:** Transactions should be as short-lived as possible to avoid blocking other operations.
- **Avoid non-database async operations:** Do not perform any async operations inside a transaction that are not related  
  to the database (e.g., network requests) as the inner transaction may be completed before.
- **Let exceptions propagate:** Do not catch exceptions within a transaction. Any unhandled exception will automatically abort the transaction and roll back any changes.
- **Avoid exceptions**: Instead of relying for unique constraint, read the db first.

### Working with Indexes

Indexes are essential for efficient querying of your data. You can create indexes on one or more fields in a store.

#### Creating an Index


**Prefer defining indexes in the `SdbDatabaseSchema`** for better maintainability and automatic migration. However, you can also create indexes manually during the `onVersionChange` callback if needed.

Indexes must be created during the `onVersionChange` callback or by defining them in the `SdbDatabaseSchema`.

```dart
var bookStore = SdbStoreRef<int, SdbModel>('books');
var serialIndex = bookStore.index<String>('serial');

// ... in onVersionChange ...
if (event.oldVersion < 2) {
  var store = db.objectStore(bookStore);
  store.createIndex(serialIndex, 'serial_number');
}
```

#### Querying with Indexes

You can use indexes to find records based on specific field values.

```dart
// Find a book by its serial number.
var book = await serialIndex.record('SN12345').get(db);
print(book?.value['title']);
```

You can also perform range queries using boundaries.

```dart
// Find all books with serial numbers between SN10000 and SN20000.
var books = await serialIndex.findRecords(db,
    boundaries: SdbBoundaries.values('SN10000', 'SN20000'));
```

### Generic Filters

SDB also provides generic filters, similar to `sembast`, for more complex queries. However, these filters are less 
efficient than using indexes because they require loading records into memory to perform the filtering.

It's always recommended to use indexes and boundaries for querying whenever possible.

```dart
// Find all books with the title 'Hamlet'.
var filteredBooks = await bookSerialIndex.findRecords(
  db,
  filter: SdbFilter.equals('title', 'Hamlet'),
);
```

### Supported types

- All idb types:
  - `int`
  - `String`
  - `Uint8List`
  - `DateTime`
  - `bool`
  - `num`
  - `double`
  - `List`
  - `Map`
- Added built-in types:
  - `SdbBlob`
  - `SdbTimestamp`
  - `SdbModel` (map)

For compatibility, only fields with type `int` or `String` can be indexed.