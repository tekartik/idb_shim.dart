# idb shim

Cross-platform IndexedDB implementation for Dart and Flutter.

idb_shim provides a browser-compatible IndexedDB API that works on:

- 🌐 Web (real IndexedDB)
- 🖥 Dart VM (IO)
- 🧪 Tests (in-memory)

It exposes the standard IndexedDB concepts:

* Database
* Transaction
* ObjectStore
* Index
* KeyRange

All operations are asynchronous and return Future.

## SDB (simple db)

Opinionated strong typed api based on idb database, which is currrently
the main available options for local storage on web with an easy support on desktop
using sqlite. Basically the lowest common denominator between indexed db and sqlite. idb_shim for io only include a sembast based implementation
(which is ok for testing).

Include [`idb_sqlite`](https://pub.dev/packages/idb_sqflite) for a solid cross process safe io implementation.

SDB (Simple DB) is a lightweight database abstraction layer for Dart that provides a unified API over IndexedDB (for web) and SQLite (for mobile and desktop). It is designed to be a simple, efficient, and cross-platform solution for data persistence.

The API is inspired by `sembast` but with a stronger emphasis on schema definition and type safety. Key features include:

- **Schema-First:** You must define your database schema, including stores and indexes, before using it. This ensures data consistency and helps prevent common errors.
- **Type-Safe:** The API is designed to be type-safe, allowing you to specify the key and value types for your stores.
- **Cross-Platform:** SDB works seamlessly on the web, mobile (iOS, Android), and desktop (Windows, Linux, macOS).
- **Efficient Queries:** Supports efficient queries using key ranges (boundaries) and indexes. In-memory filtering is also available for more complex queries.
- **Pay-as-you-go:** Data is not preloaded into memory, making it efficient for large datasets.

More information here: [sdb](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/sdb.md)

## IndexedDB Shim

* On the web (Wasm compatible, using `dart:js_interop`) it is a thin layer on top of indexed_db Web API.
* On IO (and in memory), a sembast implementation (useful for testing) is provided but prefer `idb_sqflite` for a solid
  cross-process safe io implementation. The `sembast` dependency is only present to provide a default IO implementation. On the web, the database is not loaded
  in memory and sembast is not used.

Its goal is to support the initial indexed_db api with very few changes as well as setting the base
for other implementation (idb_sqflite on top of sqflite for example).

It also allows testing your database schema and access in vm unit tests.

* Project [home page](https://tekartik.github.io/idb_shim.dart/)
* Project [source code](https://github.com/tekartik/idb_shim.dart)
* [Samples](https://tekartik.github.io/idb_shim_samples.dart) (code and live demo)

Usage example:

* [notepad_idb](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_idb): Simple flutter notepad
  working on all platforms (web/mobile/desktop)
  ([online demo](https://alextekartik.github.io/flutter_app_example/notepad_idb/))
* [demo_idb](https://github.com/alextekartik/flutter_app_example/tree/master/demo_idb): Simplest counter persistent app
  working on all platforms (web/mobile/desktop)
  ([online demo](https://alextekartik.github.io/flutter_app_example/demo_idb/))

### Why idb_shim

Use idb_shim when you need:

* Structured, transactional storage
* Indexed queries
* Cross-platform persistence
* IndexedDB-compatible semantics outside the browser

### Installation

Add the following dependency to your `pubspec.yaml`:

```yaml
dependencies:
  idb_shim: ^<latest>
```

""" Quick Start (Canonical Pattern)

```dart
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart'; // web
// import 'package:idb_shim/idb_io.dart';   // io

Future<void> main() async {
  final factory = getIdbFactory(); // browser
  // final factory = getIdbFactoryIo(); // io

  final db = await factory.open(
    'my_database',
    version: 1,
    onUpgradeNeeded: (VersionChangeEvent e) {
      final db = e.database;
      if (!db.objectStoreNames.contains('users')) {
        db.createObjectStore(
          'users',
          autoIncrement: true,
        );
      }
    },
  );

  final txn = db.transaction('users', idbModeReadWrite);
  final store = txn.objectStore('users');

  final key = await store.add({'name': 'Alice'});
  final user = await store.getObject(key);

  await txn.completed;

  print(user); // {name: Alice}
}
```

### Critical Rules (Important for Correct Usage)

These rules prevent most errors:

* Object stores must be created inside onUpgradeNeeded.
* Always await txn.completed.
* Transactions cannot be reused after completion.
* Use idbModeReadOnly for reads.
* Use idbModeReadWrite for mutations.
* All APIs return Future.

If you violate these constraints, operations may fail silently or throw.

## Usage

### Core Concepts

#### Opening a Database

```dart
final db = await factory.open(
  'db_name',
  version: 2,
  onUpgradeNeeded: (e) {
    final db = e.database;
    if (e.oldVersion < 2) {
      db.createObjectStore('items', keyPath: 'id');
    }
  },
);
```

Important:

* onUpgradeNeeded is triggered when version increases.
* You cannot create object stores outside this callback.

### Transactions

Transactions are scoped to store names.

```dart

final txn = db.transaction('items', idbModeReadOnly);
final store = txn.objectStore('items');
```

After operations:

```dart
await txn.completed;
```

Transactions auto-commit when all requests complete.

### Adding Data

```dart

final txn = db.transaction('items', idbModeReadWrite);
final store = txn.objectStore('items');

await store.add({'id': 1, 'name': 'Item 1'});
await txn.completed;
```

### Reading Data

Get by key

```dart
final item = await store.getObject(1);
```

Get all

```dart

final items = await store.getAll();
```

### Updating Data

```dart   
await store.put({'id': 1, 'name': 'Updated Item'});
```

### Deleting Data

```   
await store.delete(1);
```

### Using Indexes

Create during upgrade:

```dart
var store = db.createObjectStore(
  'users',
  keyPath: 'id');
var index = store.createIndex('by_email', 'email', unique: true);
```

Query via index:

```dart

final index = store.index('by_email');
final user = await index.getObject('test@example.com');
```

### Platform Usage

#### Web

```dart
import 'package:idb_shim/idb_browser.dart';

final factory = idbFactoryBrowser;
```

Uses real browser IndexedDB.

#### Dart VM / Flutter Desktop

```dart
import 'package:idb_shim/idb_io.dart';

final factory = idbFactorySembastIo;
```

Uses a file-backed implementation.

Prefer [`idb_sqflite`](https://pub.dev/packages/idb_sqflite) for a solid cross-process safe io implementation.

```dart
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite/sqflite.dart';

// The sqflite flutter factory
var factory = getIdbFactorySqflite(databaseFactory);
```

#### In-Memory (Testing)

```dart
import 'package:idb_shim/idb_memory.dart';

final factory = newMemoryIdbFactory();
```

No persistence.

#### Task-Oriented Examples

Repository Pattern Example

```dart
class UserRepository {
  final IdbFactory factory;

  UserRepository(this.factory);

  Future<Database> _open() {
    return factory.open(
        'app_db',
        version: 1,
        onUpgradeNeeded: (e) {
          e.database.createObjectStore(
              'users',
              keyPath: 'id');
        });
  }

  Future<void> insert(Map<String, Object?> user) async {
    final db = await _open();
    final txn = db.transaction('users', idbModeReadWrite);
    await txn.objectStore('users').put(user);
    await txn.completed;
  }

  Future<Map?> findById(Object id) async {
    final db = await _open();
    final txn = db.transaction('users', idbModeReadOnly);
    final user = await txn.objectStore('users').getObject(id);
    await txn.completed;
    return user;
  }
}
```

#### Common Mistakes

* ❌ Creating object store outside onUpgradeNeeded
* ❌ Forgetting await txn.completed
* ❌ Using transaction after completion
* ❌ Mutating data in read-only transaction
* ❌ Forgetting to increase version for schema changes

#### Versioning & Migrations

Use version numbers to evolve schema.

```dart
onUpgradeNeeded: (e) {
  final db = e.database;
  if (e.oldVersion < 1) {
    db.createObjectStore('users');
  }
  if (e.oldVersion < 2) {
    db.createObjectStore('orders');
  }
}
```

Migration code must be idempotent.

#### Migration from `dart:indexed_db`

IndexedDB Mapping (Browser → idb_shim)

| Browser API       | idb_shim         |
|-------------------|------------------|
| indexedDB.open()  | factory.open()   |
| db.transaction()  | db.transaction() |
| objectStore.add() | store.add()      |
| objectStore.put() | store.put()      |
| IDBKeyRange       | KeyRange         |

The API closely mirrors IndexedDB semantics.

Assume you have the existing (old dart:indexed_db now removed) code:

```dart
import 'dart:indexed_db';

window.indexedDB.open(dbName, version: xxx, onUpgradeNeeded: yyy);
```

This can be replaced by:

```dart
import 'package:idb_shim/idb_browser.dart'

IdbFactory idbFactory = getIdbFactory();
idbFactory.open(dbName, version: xxx, onUpgradeNeeded: yyy);
```

All other existing code remains unchanged.

### Examples

Simple notepad available [here](https://github.com/alextekartik/flutter_app_example/tree/master/notepad) running on
Flutter (iOS/Android/Web).

### Flutter support

While idb_shim over sembast is a solution on Flutter, there is an
implementation [idb_sqflite](https://pub.dev/packages/idb_sqflite) based on sqflite for mobile (iOS, MacOS and Android) and Desktop
See [Usage in flutter](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/sdb.md) for more information.

### Use the same web port when debugging

The database is stored in the browser indexeddb. Like any other web storage, it is tied to the port. (i.e. localhost:
8080 is different from localhost:8081).
When debugging, you should use the same port to keep the same indexeddb database.

### Service worker support.

In web worker you should use `idbFactoryWebWorker` instead of `idbFactoryWeb` to access the indexedDB.

### Known limitations/issues

#### Memory/Io implementation

* For autoincrement, if key is set, it cannot be set as a different type than int
* Nextunique and prevunique not supported (for now)
* No support for Cursor.source
* No generic support for blocked. It is always possible to upgrade the database, however other tabs will get blocked in
  their future calls
* Index.get: only by key is supported (no range yet)

#### Type of data

Supported types:

* Stuff that can be JSON serialized/deserialized (`num`, `String`, `bool`, `null`, `List` & `Map`)
* `DateTime` is supported as of 1.11
* `Uint8List` is supported as of 1.11
* `null` is no longer supported as a document value (although map field can be null though).

Limitations

* Cyclic dependency are not supported (per JSON serialization)
* Large float are not converted to int (native indexeddb implementation does this)
* Don't create an index on boolean value. IndexedDB does not support that, however sembast implementation allows it (
  this could change). This will only be prevented in debug.

#### Type of key

* String and num (int or double) are supported for keys

#### Native exception

* Native exception type have no match in dart so a custom DatabaseError object is created to wrap the exception

#### Ie limitation

IE 11, Edge 12 has the following limitations:

* no support for reading objectStore.autoIncrement properties
* ObjectStore.count() without argument throw a 'DataError' exception...better avoid count() on IE...
* it seems ie close the transaction 'sooner' then chrome/firefox, i.e. calling an sync function that wrap an idb calls
  makes the transaction terminate
* IDBIndex.multiEntry not supported on ie

##### Safari limitation

Safari has the following limitations (as of v 9.0)

* no support for transactions on multiple stores
* very short transaction life cycle (no await on sdk 1.12)

##### Wasm

As of 2.4 the default implementation use `js_interop` which makes it wasm compatible if you import `idb_shim.dart`
You can still use the legacy `dart:html` by importing `idb_shim_client_native_html.dart`.

As of 2.5 legacy html support has been removed. If needed, use
[`idb_shim_html_compat` git package](https://github.com/tekartik/idb_shim_more.dart/tree/main/packages/idb_shim_html_compat).

Limitations:
- DateTime is converted manually to support `DateTime` (although not supported in Firefox)
- So for compatibility, data is jsified and dartified using custom encoder. To see if this could be removed in the
  future.
