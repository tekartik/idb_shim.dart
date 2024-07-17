# SDB

SDB stands for Simple DB, it provides a dart API on top of indexed_db or sqlite.
The API is similar to sembast but requires some schema configuration.
- Each store must be declared and added once to a database.
- Queries are limited to boundaries and indexes.

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
  }
  // Uses sqflite on desktop and mobile
  factory = sdbFactorySqflite;
}
```

### Open a database

#### The schema

You must first define a schema for each store/table, defining
the key type and the value type.
Good options is to use `int` as a key and `SdbModel` as a value.

```dart
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
- Single index (for now)

### Creating index

TODO - Yes it's possible but not documented yet.
