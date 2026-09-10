---
name: idb-shim-database
description: >-
  Use when writing Dart or Flutter code with package:idb_shim's IndexedDB-shaped
  API (IdbFactory, Database, open with onUpgradeNeeded, createObjectStore,
  createIndex, Transaction, ObjectStore add/put/getObject/getAll/delete,
  Index, KeyRange, openCursor, idbModeReadWrite) and when choosing a factory
  per platform: idbFactoryWeb/idbFactoryBrowser (web), idbFactorySembastIo or
  getIdbFactoryPersistent (Dart VM), idbFactoryMemory/newIdbFactoryMemory
  (tests), idb_sqflite on Flutter mobile/desktop, conditional imports,
  sandbox, logger, import/export and copyDatabase helpers.
---

# idb_shim: IndexedDB API on every platform

`package:idb_shim` exposes the browser IndexedDB model (`IdbFactory`,
`Database`, `Transaction`, `ObjectStore`, `Index`, `KeyRange`, cursors) with
three backends: real IndexedDB on the web (`dart:js_interop`, wasm ready), a
sembast file backend on the Dart VM, and a sembast in-memory backend for tests.
The same code runs everywhere; only the `IdbFactory` changes. For Flutter
mobile/desktop, the companion package `idb_sqflite` provides an SQLite backend
with the same `IdbFactory` interface.

```dart
import 'package:idb_shim/idb_shim.dart';

Future<void> run(IdbFactory factory) async {
  final db = await factory.open('app.db', version: 1,
      onUpgradeNeeded: (VersionChangeEvent e) {
    e.database.createObjectStore('notes', autoIncrement: true);
  });
  final txn = db.transaction('notes', idbModeReadWrite);
  final key = await txn.objectStore('notes').add({'title': 'hello'});
  await txn.completed;
  db.close();
}
```

## Guidelines

### Imports and factory per platform

* `package:idb_shim/idb_shim.dart` (alias `idb_client.dart`) gives the whole
  API plus `idbFactoryMemory`, `newIdbFactoryMemory()`, `idbFactoryWeb`,
  `idbFactoryNative`, `idbFactoryWebWorker` and `idbFactoryWebSupported`. It
  compiles on every platform; the web getters throw `UnsupportedError` when
  called on the VM. `package:idb_shim/idb.dart` is the interface only.
* Web: `idbFactoryWeb` (same object as `idbFactoryNative`) is the browser
  IndexedDB. `idbFactoryWebWorker` is the one to use inside a web/service
  worker. `package:idb_shim/idb_browser.dart` adds `idbFactoryBrowser`, which
  falls back to `idbFactoryMemory` when IndexedDB is unavailable, and
  `getIdbFactory([name])` (not recommended).
* Dart VM / CLI: `package:idb_shim/idb_io.dart` gives `idbFactorySembastIo`
  (database names are file paths relative to the current directory),
  `getIdbFactorySembastIo(path)` and `getIdbFactoryPersistent(path)` (both
  root every database below `path`). This file imports `dart:io` through
  `sembast_io`: import it only from VM-only code or behind a conditional
  import.
* Tests: `package:idb_shim/idb_client_memory.dart` gives `idbFactoryMemory`
  (one shared in-memory factory for the whole process), `newIdbFactoryMemory()`
  (fresh, isolated: prefer it per test) and `idbFactoryMemoryFs` (in-memory
  virtual file system).
* Flutter mobile/desktop: depend on `idb_sqflite` and use `idbFactorySqflite`
  (`package:idb_sqflite/idb_sqflite.dart`) or
  `getIdbFactorySqflite(databaseFactory)` with `sqflite` or
  `sqflite_common_ffi`; keep `idbFactoryWeb` on the web (`kIsWeb`). The
  sembast io backend is for tests and simple tools, it is not cross-process
  safe.
* In pure Dart, pick the backend with a conditional import on
  `dart.library.js_interop` (see the example below). `kIdbDartIsWeb`
  (`idb_shim.dart`) is a compile-time bool for the same test at runtime.
* `IdbFactory.persistent` is false for memory factories; `name` identifies the
  backend (`idbFactoryNameMemory`, `idbFactoryNameSembastIo`,
  `idbFactoryNameNative`...).

### Opening and upgrading

* `factory.open(name, version: n, onUpgradeNeeded: (VersionChangeEvent e) {...})`
  returns a `Future<Database>`. `onUpgradeNeeded` runs only when the stored
  version is lower than `version` (or the database is new). `version` must be
  a positive int; `0` throws `ArgumentError`.
* `createObjectStore`, `deleteObjectStore`, `createIndex` and `deleteIndex` are
  only legal inside `onUpgradeNeeded`. Use `e.database` (idb_shim convenience)
  and `e.transaction` there; check `e.oldVersion` to write incremental,
  idempotent migrations (`if (e.oldVersion < 2) {...}`) and guard with
  `db.objectStoreNames.contains(name)` when unsure.
* `createObjectStore(name, {keyPath, autoIncrement})`: with `keyPath: 'id'`
  the key is read from the value (`value['id']`); with `autoIncrement: true`
  the key is generated (int). Without either, pass the key explicitly to
  `add`/`put`. Do not pass a key to `add`/`put` when the store has a
  `keyPath`.
* `store.createIndex(name, keyPath, {unique, multiEntry})`: `keyPath` is a
  `String` or a `List<String>` (composite index). Do not index boolean fields
  (IndexedDB rejects it; sembast tolerates it).
* Opening with a lower `version` than the stored one fails. For dev-time hot
  restarts use the `IdbFactoryExt.openOnDowngradeDelete(...)` extension
  (same parameters as `open`), which deletes and re-creates the database on
  downgrade. Never ship it for user data.
* `Database.onVersionChange` fires when another tab/connection upgrades the
  database: close the database in the handler. `close()` is synchronous.
* `factory.deleteDatabase(name)` removes a database; close open connections
  first or other tabs get blocked.

### Transactions

* `db.transaction(storeName, mode)` or `db.transaction([s1, s2], mode)` /
  `db.transactionList([...], mode)`; `mode` is `idbModeReadOnly` or
  `idbModeReadWrite` (strings, no enum). Every store touched must be in the
  scope, otherwise `DatabaseStoreNotFoundError`.
* Get stores from the transaction: `txn.objectStore(name)`, then call the
  request methods. Always `await txn.completed` (a `Future<Database>`)
  before considering writes durable and before starting dependent work.
* A transaction auto-commits when no request is pending. Do not `await`
  anything that is not an idb request (network, timers, `Future.delayed`,
  a lock) between two requests: the transaction is finished when you come
  back and the next request throws. Prepare data before opening the
  transaction.
* `txn.abort()` rolls back. A failed request also aborts the transaction.
* A transaction object cannot be reused after completion; open a new one.
* Writes in a read-only transaction throw `DatabaseReadOnlyError`.

### Requests on ObjectStore and Index

* `store.add(value, [key])` inserts (fails on existing key), `store.put(value,
  [key])` inserts or updates; both return the key. `value` cannot be null.
* `store.getObject(key)` returns the value or null; `store.getKey(key)`,
  `store.getAll([query, count])`, `store.getAllKeys([query, count])`,
  `store.count([keyOrRange])`, `store.delete(keyOrRange)`, `store.clear()`.
  `query` is a key or a `KeyRange`.
* `store.index(name)` gives an `Index` with `get(key)` (first matching value),
  `getKey(key)` (primary key), `getAll`, `getAllKeys`, `count`. Note the name
  difference: `Index.get`, `ObjectStore.getObject`.
* `KeyRange.only(v)`, `KeyRange.lowerBound(v, [open])`,
  `KeyRange.upperBound(v, [open])`, `KeyRange.bound(lower, upper, [lowerOpen,
  upperOpen])`; `open` defaults to false (bound included).
* Keys must be `int`, `double` or `String` (arrays for composite indexes).
  Values must be JSON-like (`num`, `String`, `bool`, `List`, `Map`) plus
  `DateTime` and `Uint8List`. No cyclic structures, no `null` value.
* Read values are `Object`; cast with `as Map` / `as Map<String, Object?>`
  (`Map` values come back as `Map<String, Object?>`).

### Cursors

* `store.openCursor({key, range, direction, autoAdvance})` and
  `openKeyCursor(...)` return a `Stream<CursorWithValue>` /
  `Stream<Cursor>`; `Index` has the same two methods (`cursor.key` is then
  the index key, `cursor.primaryKey` the record key). `direction` is
  `idbDirectionNext` or `idbDirectionPrev` (`nextunique`/`prevunique` are not
  supported by the sembast backends).
* With `autoAdvance: true` the stream delivers every row and closes at the
  end (`await stream.listen(...).asFuture()` is fine). With
  `autoAdvance: false` (the default) you must call `cursor.next()` or
  `cursor.advance(n)` in the listener or the stream stops after the first
  row; stopping early is how you break out, but the stream then never
  closes: do not await it, `await txn.completed` instead.
* `cursor.update(value)` and `cursor.delete()` need a read-write transaction.
  The stream ends when the transaction completes; still `await txn.completed`.
* Prefer the helpers in `package:idb_shim/utils/idb_cursor_utils.dart`:
  `stream.toRowList({limit, offset, matcher})` gives `List<CursorRow>`
  (`key`, `primaryKey`, `value`), `toValueList`, `toKeyRowList`,
  `toKeyList`, `toPrimaryKeyList`. They drive the cursor themselves, so open
  it without `autoAdvance`.

### Errors

* Failures are `DatabaseError` subclasses (`DatabaseReadOnlyError`,
  `DatabaseStoreNotFoundError`, `DatabaseIndexNotFoundError`,
  `DatabaseNoKeyError`, `DatabaseInvalidKeyError`) or `DatabaseException`;
  native browser errors are wrapped in `DatabaseError` with the DOM message.
  Catch `DatabaseError` (an `Error`) explicitly when you want to recover.

## Examples

### Schema with versioned migrations and CRUD

```dart
import 'package:idb_shim/idb_shim.dart';

const notesStore = 'notes';
const byDateIndex = 'by_date';

Future<Database> openNotesDb(IdbFactory factory) {
  return factory.open('notes.db', version: 2,
      onUpgradeNeeded: (VersionChangeEvent e) {
    final db = e.database;
    if (e.oldVersion < 1) {
      db.createObjectStore(notesStore, autoIncrement: true);
    }
    if (e.oldVersion < 2) {
      // Reach an existing store through the upgrade transaction.
      final store = e.transaction.objectStore(notesStore);
      store.createIndex(byDateIndex, 'date');
    }
  });
}

Future<int> addNote(Database db, String title, String date) async {
  final txn = db.transaction(notesStore, idbModeReadWrite);
  final key = await txn.objectStore(notesStore).add({
    'title': title,
    'date': date,
  });
  await txn.completed;
  return key as int;
}

Future<Map<String, Object?>?> getNote(Database db, int key) async {
  final txn = db.transaction(notesStore, idbModeReadOnly);
  final value = await txn.objectStore(notesStore).getObject(key);
  await txn.completed;
  return value as Map<String, Object?>?;
}

Future<void> updateNote(Database db, int key, Map<String, Object?> note) async {
  final txn = db.transaction(notesStore, idbModeReadWrite);
  await txn.objectStore(notesStore).put(note, key);
  await txn.completed;
}

Future<void> deleteNote(Database db, int key) async {
  final txn = db.transaction(notesStore, idbModeReadWrite);
  await txn.objectStore(notesStore).delete(key);
  await txn.completed;
}
```

### Picking the factory with conditional imports (pure Dart)

```dart
// lib/src/db_factory.dart
import 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart'
    as impl;
import 'package:idb_shim/idb.dart';

IdbFactory get appIdbFactory => impl.appIdbFactory;
```

```dart
// lib/src/db_factory_io.dart
import 'package:idb_shim/idb_io.dart';

IdbFactory get appIdbFactory => getIdbFactoryPersistent('.local/db');
```

```dart
// lib/src/db_factory_web.dart
import 'package:idb_shim/idb_browser.dart';

IdbFactory get appIdbFactory => idbFactoryBrowser;
```

In Flutter, skip the conditional import and use `kIsWeb`:

```dart
import 'package:flutter/foundation.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_sqflite/idb_sqflite.dart';

IdbFactory get appIdbFactory => kIsWeb ? idbFactoryWeb : idbFactorySqflite;
```

### Index lookups and key ranges

```dart
import 'package:idb_shim/idb_shim.dart';

Future<Database> openUsers(IdbFactory factory) =>
    factory.open('users.db', version: 1, onUpgradeNeeded: (e) {
      final store = e.database.createObjectStore('users', keyPath: 'id');
      store.createIndex('by_email', 'email', unique: true);
      store.createIndex('by_age', 'age');
    });

Future<void> queries(Database db) async {
  final txn = db.transaction('users', idbModeReadWrite);
  final store = txn.objectStore('users');
  // keyPath 'id': the key comes from the value, no second argument.
  await store.put({'id': 'u1', 'email': 'a@x.org', 'age': 31});
  await store.put({'id': 'u2', 'email': 'b@x.org', 'age': 45});

  final user = await store.index('by_email').get('a@x.org');
  final idOfB = await store.index('by_email').getKey('b@x.org'); // 'u2'
  final adults = await store
      .index('by_age')
      .getAll(KeyRange.bound(18, 65)); // both bounds included
  final firstTwo = await store.getAll(null, 2);
  final howMany = await store.count(KeyRange.lowerBound('u1', true));
  await txn.completed;
  print([user, idOfB, adults.length, firstTwo.length, howMany]);
}
```

### Cursor iteration and in-place update

```dart
import 'package:idb_shim/idb_shim.dart';

Future<void> archiveOld(Database db, String beforeDate) async {
  final txn = db.transaction('notes', idbModeReadWrite);
  final index = txn.objectStore('notes').index('by_date');
  // autoAdvance: the stream delivers every matching row.
  await index
      .openCursor(range: KeyRange.upperBound(beforeDate, true), autoAdvance: true)
      .listen((CursorWithValue cursor) {
    final note = Map<String, Object?>.from(cursor.value as Map);
    note['archived'] = true;
    cursor.update(note);
  }).asFuture<void>();
  await txn.completed;
}

Future<List<Object>> firstKeys(Database db, int limit) async {
  final txn = db.transaction('notes', idbModeReadOnly);
  final keys = <Object>[];
  var count = 0;
  // Manual advance: call next() or the stream stops after one row.
  // Do not await the stream: it never closes once you stop advancing.
  txn.objectStore('notes').openKeyCursor().listen((Cursor cursor) {
    keys.add(cursor.primaryKey);
    if (++count < limit) {
      cursor.next();
    }
  });
  await txn.completed; // completes once no request is pending
  return keys;
}
```

### Cursor stream helpers

```dart
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/utils/idb_cursor_utils.dart';

Future<List<Map>> pageNotes(Database db, {int offset = 0, int limit = 20}) async {
  final txn = db.transaction('notes', idbModeReadOnly);
  // Open without autoAdvance: toRowList drives the cursor.
  final rows = await txn
      .objectStore('notes')
      .openCursor(direction: idbDirectionPrev)
      .toRowList(offset: offset, limit: limit);
  await txn.completed;
  return rows.map((CursorRow row) => row.value as Map).toList();
}
```

### Unit test with an isolated memory factory

```dart
import 'package:idb_shim/idb_client_memory.dart';
import 'package:test/test.dart';

void main() {
  late IdbFactory factory;
  setUp(() {
    factory = newIdbFactoryMemory(); // nothing shared between tests
  });

  test('add and read', () async {
    final db = await factory.open('t.db', version: 1,
        onUpgradeNeeded: (e) => e.database.createObjectStore('s'));
    var txn = db.transaction('s', idbModeReadWrite);
    await txn.objectStore('s').put({'v': 1}, 'k');
    await txn.completed;

    txn = db.transaction('s', idbModeReadOnly);
    expect(await txn.objectStore('s').getObject('k'), {'v': 1});
    await txn.completed;
    db.close();
  });
}
```

## Common mistakes

* Calling `createObjectStore`/`createIndex` outside `onUpgradeNeeded`, or
  forgetting to bump `version` after changing the schema (the callback never
  runs).
* Awaiting a non-database future inside a transaction; the transaction has
  already committed when the next request is issued.
* Forgetting `await txn.completed`, then closing the database or reading in
  a new transaction before the write landed.
* Passing an explicit key to `add`/`put` on a store that has a `keyPath`.
* Opening a cursor without `autoAdvance: true` and never calling
  `cursor.next()`: only the first row is delivered.
* Storing `null`, a class instance or a `DateTime` inside an index key path.
* Using `idb_shim/idb_io.dart` in code that is also compiled for the web.
* Sharing `idbFactoryMemory` across tests and being surprised by leftover
  databases; use `newIdbFactoryMemory()` or `deleteDatabase` in `setUp`.

## More

See [references/advanced.md](references/advanced.md) for factory sandboxing
(`sandbox(path:)`), the debug logger (`getIdbFactoryLogger`,
`debugWrapInLogger`), database copy/export/import
(`copyDatabase`, `idbExportDatabase`, `idbImportDatabase`), the sembast
bridge (`IdbFactorySembast`, `openFromSembastDatabase`), the list-returning
cursor functions of `utils/idb_utils.dart` and backend limitations.
