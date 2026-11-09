# idb_shim

[![pub package](https://img.shields.io/pub/v/idb_shim.svg)](https://pub.dev/packages/idb_shim)
[![Run CI](https://github.com/tekartik/idb_shim.dart/actions/workflows/run_ci.yml/badge.svg)](https://github.com/tekartik/idb_shim.dart/actions/workflows/run_ci.yml)

The IndexedDB API for Dart and Flutter, on every platform: the real browser
IndexedDB on the web (`dart:js_interop`, wasm ready), a sembast based
implementation on the Dart VM and in memory (tests), and SQLite through
[`idb_sqflite`](https://pub.dev/packages/idb_sqflite) on Flutter mobile and
desktop. The same code runs everywhere, only the factory changes.

It comes with two APIs:

| API | Import | Use it for |
|---|---|---|
| **idb**, the IndexedDB API (`IdbFactory`, `Database`, `Transaction`, `ObjectStore`, `Index`, `KeyRange`, cursors) | `package:idb_shim/idb_shim.dart` | Code that follows IndexedDB, existing IndexedDB code, full control |
| **sdb** (Simple DB), a typed API on top of idb (schema, typed stores and indexes, boundaries, filters, joins, change listeners) | `package:idb_shim/sdb.dart` | New apps: less code, typed keys, schema driven upgrades. See [doc/sdb.md](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/sdb.md) |

## Getting started

```sh
# Dart
dart pub add idb_shim
# Flutter (sqflite gives the SQLite implementation on mobile and desktop)
flutter pub add idb_shim idb_sqflite sqflite
```

### Pick the factory for your platform

| Platform | Import | idb factory | sdb factory |
|---|---|---|---|
| Web, Flutter web (browser IndexedDB) | `package:idb_shim/idb_browser.dart` | `idbFactoryWeb` (`idbFactoryBrowser` falls back to memory when IndexedDB is missing) | `sdbFactoryWeb` |
| Web worker | `package:idb_shim/idb_shim.dart` | `idbFactoryWebWorker` | `sdbFactoryWebWorker` |
| Flutter Android, iOS, macOS, Windows, Linux (SQLite, cross process safe) | [`idb_sqflite`](https://pub.dev/packages/idb_sqflite) | `getIdbFactorySqflite(sqflite.databaseFactory)` | `sdbFactoryFromSqflite(sqflite.databaseFactory)` (`package:idb_sqflite/sdb_sqflite.dart`) |
| Dart VM (CLI, server), single process | `package:idb_shim/idb_io.dart` | `idbFactorySembastIo`, or `getIdbFactorySembastIo(rootPath)` | `sdbFactoryIo` |
| Unit tests, any platform (in memory, nothing saved) | `package:idb_shim/idb_shim.dart` | `newIdbFactoryMemory()` (a new empty one) or `idbFactoryMemory` | `newSdbFactoryMemory()` or `sdbFactoryMemory` |

`idb_io.dart` imports `dart:io`: do not import it in web code (use conditional
imports to pick the factory, see
[doc/usage_in_flutter.md](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/usage_in_flutter.md)).
On the VM the web factories exist but throw when used.

### Minimal example (idb)

```dart
import 'package:idb_shim/idb_shim.dart';

Future<void> main() async {
  // In memory here, take the factory of your platform from the table above.
  var factory = newIdbFactoryMemory();

  // Open the database once, keep it open while the app runs.
  var db = await factory.open(
    'my_app.db',
    version: 1,
    onUpgradeNeeded: (VersionChangeEvent event) {
      // Called on creation (oldVersion 0) and when the version increases:
      // the only place where stores and indexes are created or deleted.
      var db = event.database;
      if (event.oldVersion < 1) {
        var store = db.createObjectStore('users', autoIncrement: true);
        store.createIndex('by_email', 'email', unique: true);
      }
    },
  );

  // Write in a read-write transaction.
  var txn = db.transaction('users', idbModeReadWrite);
  var store = txn.objectStore('users');
  var key = await store.add({'name': 'Alice', 'email': 'alice@example.com'});
  await txn.completed;

  // Read in a read-only transaction.
  txn = db.transaction('users', idbModeReadOnly);
  store = txn.objectStore('users');
  print(await store.getObject(key)); // {name: Alice, email: alice@example.com}
  print(await store.index('by_email').get('alice@example.com'));
  await txn.completed;

  db.close();
}
```

### Minimal example (sdb)

```dart
import 'package:idb_shim/sdb.dart';

// A store with int keys and map values.
var bookStore = SdbStoreRef<int, SdbModel>('book');

Future<void> main() async {
  var factory = newSdbFactoryMemory();
  var db = await factory.openDatabase(
    'books.db',
    options: SdbOpenDatabaseOptions(
      version: 1,
      // The schema creates and upgrades the stores and indexes.
      schema: SdbDatabaseSchema(stores: [bookStore.schema(autoIncrement: true)]),
    ),
  );
  var key = await bookStore.add(db, {'title': 'Dune'});
  print(await bookStore.record(key).getValue(db)); // {title: Dune}
  await db.close();
}
```

More in [doc/sdb.md](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/sdb.md),
[doc/sdb_iterate.md](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/sdb_iterate.md)
and [doc/sdb_join.md](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/sdb_join.md).

## idb API

### Open and upgrade

`open` takes a version: when it is higher than the stored one,
`onUpgradeNeeded` runs inside a version change transaction. Test
`event.oldVersion` to apply each step once:

```dart
var db = await factory.open(
  'my_app.db',
  version: 2,
  onUpgradeNeeded: (VersionChangeEvent event) {
    var db = event.database;
    if (event.oldVersion < 1) {
      db.createObjectStore('users', autoIncrement: true);
    }
    if (event.oldVersion < 2) {
      db.createObjectStore('orders', keyPath: 'id');
    }
  },
);
```

Opening without a version opens the current one. Do not open with a version
lower than the stored one: it fails on the web (VersionError) and, with an
`onUpgradeNeeded`, on the sembast implementation (without one, sembast lowers
the version). `IdbFactory.openOnDowngradeDelete` deletes the database
instead.

### Transactions

A transaction covers one store or a list of stores, read-only
(`idbModeReadOnly`) or read-write (`idbModeReadWrite`). It commits by itself
once no request is pending: do not await anything else than its own requests
(no network, no timer) or it is already committed. Wait for
`await txn.completed` to know the writes are saved; `txn.abort()` cancels them.
A request that fails aborts the transaction.

```dart
var txn = db.transactionList(['users', 'orders'], idbModeReadWrite);
await txn.objectStore('users').put({'name': 'Bob'}, 2);
await txn.objectStore('orders').put({'id': 'o1', 'user': 2});
await txn.completed;
```

### Store operations

| Method | Does |
|---|---|
| `add(value, [key])` | Inserts, fails if the key exists |
| `put(value, [key])` | Inserts or replaces |
| `getObject(key)` | The value, or null |
| `getAll([keyOrRange, count])`, `getAllKeys(...)` | Values or keys in key order |
| `count([keyOrRange])` | Number of records |
| `delete(keyOrRange)`, `clear()` | Removes records |
| `openCursor(...)`, `openKeyCursor(...)` | Walks the records, see below |

The key is given (`put(value, key)`) for a store without key path, or read
from the value for a store with a `keyPath` (`'id'`, `'a.b'` or an array of
key paths). `autoIncrement: true` generates int keys.

### Indexes, key ranges and cursors

```dart
var txn = db.transaction('users', idbModeReadOnly);
var index = txn.objectStore('users').index('by_email');
var user = await index.get('alice@example.com'); // first match, or null
var keys = await index.getAllKeys(KeyRange.bound('a', 'b', false, true));

// autoAdvance walks every record, cursorToList (idb_utils.dart) collects them.
var rows = await cursorToList(
  txn.objectStore('users').openCursor(direction: idbDirectionPrev, autoAdvance: true),
);
await txn.completed;
```

Without `autoAdvance`, call `cursor.next()` (or `advance(n)`) in the listener,
and `cursor.update(value)` / `cursor.delete()` in a read-write transaction.
`package:idb_shim/utils/idb_utils.dart` also has `copyDatabase`, and
`package:idb_shim/utils/idb_import_export.dart` exports and imports a
database (`idbExportDatabase`, `idbImportDatabase`).

## Common pitfalls

* Creating or deleting a store or an index outside `onUpgradeNeeded`, or
  forgetting to increase the version for a schema change.
* Awaiting something else (http, `Future.delayed`, a lock) inside a
  transaction: it commits in between and the next request fails.
* Writing in a read-only transaction.
* Opening the database for each operation: open it once and keep it.
* Using the sembast io factory from several processes (or isolates) on the
  same file: use `idb_sqflite` then.
* Values must be maps, lists, strings, numbers, booleans, `DateTime` or
  `Uint8List` (no custom classes: convert them to maps first).

## Platform notes

* Web: the data is per origin, `localhost:8080` and `localhost:8081` are two
  different databases; debug on a fixed port.
* Web workers: use `idbFactoryWebWorker`.
* Dart VM: `idbFactorySembastIo` stores each database in a single sembast
  file (fine for tools and tests).
* Flutter: see
  [doc/usage_in_flutter.md](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/usage_in_flutter.md).
* Migrating from the removed `dart:indexed_db`: replace
  `window.indexedDB.open(...)` with `idbFactoryWeb.open(...)`
  (`package:idb_shim/idb_browser.dart`), the rest of the code is the same.
  The legacy `dart:html` implementation lives in the
  [`idb_shim_html_compat`](https://github.com/tekartik/idb_shim_more.dart/tree/main/packages/idb_shim_html_compat)
  git package.

## Supported types

* Values: `num`, `String`, `bool`, `null` (as a field), `List`, `Map`,
  `DateTime` and `Uint8List`. A value itself cannot be null.
* Keys: `String`, `num` and arrays of them (array key paths).
* Booleans, null and maps are not keys: a record whose indexed field holds
  one is not in that index.

See [doc/known_limitations.md](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/known_limitations.md)
for the limits of the sembast (io, memory) implementation and of older
browsers.

## Examples

* [example/example.dart](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/example/example.dart)
  (idb, Dart VM) and
  [example/sdb_example.dart](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/example/sdb_example.dart)
  (sdb).
* [notepad_sdb](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_sdb)
  ([online demo](https://notepad_sdb.surge.sh)) and
  [demo_sdb](https://github.com/alextekartik/flutter_app_example/tree/master/demo_sdb)
  ([online demo](https://demo_sdb.surge.sh)): Flutter apps on sdb (web,
  mobile, desktop).
* [notepad_idb](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_idb)
  ([online demo](https://alextekartik.github.io/flutter_app_example/notepad_idb/))
  and [demo_idb](https://github.com/alextekartik/flutter_app_example/tree/master/demo_idb)
  ([online demo](https://alextekartik.github.io/flutter_app_example/demo_idb/)):
  the same on idb.
