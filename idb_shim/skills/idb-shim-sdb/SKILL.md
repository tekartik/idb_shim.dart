---
name: idb-shim-sdb
description: >-
  Use when writing Dart or Flutter code with the typed SDB (Simple DB) API of
  package:idb_shim (import package:idb_shim/sdb.dart): SdbFactory
  (sdbFactoryMemory, sdbFactoryIo, sdbFactoryWeb, sdbFactorySqflite),
  SdbStoreRef, SdbModel, SdbDatabaseSchema/SdbOpenDatabaseOptions,
  openDatabase with onVersionChange, SdbRecordRef get/put/delete,
  findRecords/findRecord/count with SdbBoundaries and SdbFilter,
  SdbIndexRef/index2 composite indexes, inStoreTransaction/inStoresTransaction,
  iterate, joins between two stores (joinIterate/findJoinRows/findJoinRecords/
  findJoinedRecords/joinCount, SdbJoinTarget, SdbJoinFindOptions),
  onSnapshot/onSnapshots, SdbTimestamp and SdbBlob.
---

# idb_shim SDB: schema-first typed database

SDB is the opinionated, strongly typed layer of `package:idb_shim` on top of
the IndexedDB model. A store is a `SdbStoreRef<K, V>` (`K` is `int` or
`String`, `V` is usually `SdbModel`, i.e. `Map<String, Object?>`); records,
indexes and queries are typed by it. The same code runs on the web
(IndexedDB), on the Dart VM (sembast file), in memory (tests) and on Flutter
mobile/desktop through `idb_sqflite` (SQLite).

```dart
import 'package:idb_shim/sdb.dart';

final notes = SdbStoreRef<int, SdbModel>('notes');

Future<void> run(SdbFactory factory) async {
  final db = await factory.openDatabase('app.db',
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [notes.schema(autoIncrement: true)]),
      ));
  final key = await notes.add(db, {'title': 'hello'});
  final snapshot = await notes.record(key).get(db);
  print(snapshot?.value['title']); // hello
  await db.close();
}
```

## Guidelines

### Factory and platform

* Import `package:idb_shim/sdb.dart` (everything SDB, no classic idb
  symbols). `package:idb_shim/idb_sdb.dart` re-exports both APIs.
* Factories: `sdbFactoryMemory` (shared in-memory), `newSdbFactoryMemory()`
  (isolated, use in tests), `sdbFactoryIo` (sembast files, Dart VM only,
  names are file paths), `sdbFactoryWeb` (browser IndexedDB),
  `sdbFactoryWebWorker` (inside a worker). `sdbFactoryFromIdb(idbFactory)`
  wraps any classic `IdbFactory`; `factory.idbFactory` gives it back.
* Flutter mobile/desktop: depend on `idb_sqflite` and use
  `sdbFactorySqflite` (`package:idb_sqflite/sdb_sqflite.dart`, with `sqflite`
  or `sqflite_common_ffi` set as `databaseFactory`). Keep `sdbFactoryWeb` on
  the web. Choose with `kIsWeb` in Flutter or `kSdbDartIsWeb` in pure Dart.
  `sdbFactoryIo` is fine for tests and CLI tools, not for production apps.
* `sdb.dart` imports the io backend; it still compiles for the web but never
  touch `sdbFactoryIo` there.

### Stores, keys, values

* Declare store references once as top-level/`final` fields:
  `SdbStoreRef<int, SdbModel>('books')`. `K` must be `int` or `String`
  (`ArgumentError` otherwise). `int` keys are generated when the store is
  `autoIncrement`; `String` keys are supplied by you.
* `V` is normally `SdbModel`. Values may contain `num`, `String`, `bool`,
  `List`, `Map`, `DateTime`, `Uint8List`, `SdbTimestamp` and `SdbBlob`
  (`SdbTimestamp` = sembast `Timestamp`: `SdbTimestamp.now()`,
  `SdbTimestamp.fromDateTime(dt)`, `toDateTime()`). Those two are encoded by
  the default `SdbCodec.defaultCodec`; pass `codec: SdbCodec.none` in
  `SdbOpenDatabaseOptions` to store raw data only.
* `store.record(key)` is a `SdbRecordRef` (no I/O). `store.records(keys)`
  gives a list of them.

### Opening and schema

* `factory.openDatabase(name, options: SdbOpenDatabaseOptions(version:,
  schema:, onVersionChange:, codec:))`. The `version`, `schema` and
  `onVersionChange` named parameters directly on `openDatabase` are
  deprecated; use `options`.
* Prefer `schema`: `SdbDatabaseSchema(stores: [store.schema(autoIncrement:
  true, keyPath: SdbKeyPath.single('id'), indexes: [index.schema(keyPath:
  'field', unique: false)])])`. On version increase the schema is diffed:
  missing stores/indexes are created, stores and indexes absent from the
  schema are **deleted**, a changed key path/autoIncrement/unique throws
  `StateError` (create a new store/index instead).
* `onVersionChange: (SdbVersionChangeEvent event)` is called after the
  schema is applied (or alone when there is no schema). Inside, use
  `event.db` (`SdbOpenDatabase`): `createStore(storeRef, {keyPath,
  autoIncrement})` (autoIncrement defaults to true for `int` keys),
  `objectStore(storeRef)`, `deleteStore(name)`, `objectStoreNames`; on the
  returned `SdbOpenStoreRef`: `createIndex(indexRef, keyPath, {unique})`,
  `createIndex2(index2Ref, path1, path2)`, `deleteIndex(name)`. Data can be
  read/written there through `event.transaction`.
* Bump `version` whenever the schema changes. `openDatabaseOnDowngradeDelete`
  (extension on `SdbFactory`, same `options`) deletes the database when a
  lower version is requested: dev/hot-restart convenience only.
* `db.readSchemaDef()` returns the live `SdbDatabaseSchemaDef` (debugging);
  `db.version`, `db.name`, `db.storeNames`, `await db.close()`.

### Reading and writing

Every store/record/index method takes a `SdbClient` first: pass the
`SdbDatabase` (an implicit transaction is created) or a `SdbTransaction`.

* `store.add(client, value)` returns the new key. `store.put(client, value)`
  only for stores with a `keyPath` (returns the key read from the value).
  For an explicit key use `store.record(key).put(client, value)`.
* `store.record(key).get(client)` returns `SdbRecordSnapshot?` (`key`,
  `value`, `ref`), `getValue(client)` returns `V?`, `exists(client)`,
  `delete(client)`.
* `store.findRecords(client, {boundaries, filter, offset, limit,
  descending})` returns `List<SdbRecordSnapshot<K, V>>` (`.values` and
  `.keys` extensions); `findRecord` returns the first or null;
  `findRecordKeys` returns keys only; `streamRecords` streams; `count`
  and `delete` accept `boundaries`. The same parameters can be bundled in
  `options: SdbFindOptions<K>(...)`, which takes precedence.
* `boundaries` is a key range on the primary key: `SdbBoundaries.values(1,
  10)` (lower included, upper excluded), `SdbBoundaries(SdbLowerBoundary(1),
  SdbUpperBoundary(10, include: true))`, `SdbBoundaries.lowerValue(5)`,
  `SdbBoundaries.upperValue(5)`, or `store.lowerBoundary(v)` /
  `store.upperBoundary(v)`. Boundaries are applied by the engine; use them
  for every query that can.
* `filter` is a sembast `Filter` (`SdbFilter.equals('field', v)`,
  `SdbFilter.greaterThan`, `SdbFilter.inList`, `SdbFilter.matches`,
  `SdbFilter.and([...])`, `SdbFilter.or([...])`, `SdbFilter.custom((record)
  => ...)`). It runs **in memory** after boundaries, so combine it with
  boundaries or an index on large stores. Not supported by `findRecordKeys`.

### Indexes

* Declare next to the store: `final byAuthor = books.index<String>('author')`;
  `I` must be `int`, `String` or `SdbTimestamp`. Composite:
  `books.index2<String, int>('author_year')`, `index3`, `index4`; their key
  type is a record `(I1, I2)`.
* Create in the schema with `byAuthor.schema(keyPath: 'author')`
  (composite: `keyPath: ['author', 'year']` or `schema2('author', 'year')`),
  or in `onVersionChange` with `createIndex` / `createIndex2`.
* `index.record(indexKey).get(client)` returns the first
  `SdbIndexRecordSnapshot` (`key` primary, `indexKey`, `value`) or null;
  `getValue`, `getKey` (primary key), `findRecords`, `findKeys`, `count`,
  `delete` act on every record with that index key.
* `index.findRecords(client, {boundaries, filter, offset, limit,
  descending})`: `boundaries` is typed by the index key
  (`SdbBoundaries.values('A', 'M')`, composite:
  `SdbBoundaries.values(('cat', 0), ('cat', 1000))` or
  `index2.lowerBoundary('cat', 0)`). Also `findRecord`, `findRecordKeys`,
  `streamRecords`, `count`, `delete`, `iterate`.
* `unique: true` makes `add`/`put` fail on duplicates; check first with
  `index.record(v).getKey(client) == null` rather than catching the error.

### Transactions

* `db.inStoreTransaction(store, SdbTransactionMode.readWrite, (txn) async
  {...})` for one store: pass `txn` as the client to the store methods, or
  use `txn.txnStore` / the shortcuts `txn.add(value)`, `txn.put(key,
  value)`, `txn.getRecord(key)`, `txn.delete(key)`, `txn.findRecords(...)`.
* `db.inStoresTransaction([s1, s2], mode, (txn) async {...})` for several
  stores: `txn.store(s1)` gives a `SdbTransactionStoreRef` with `getRecord`,
  `getValue`, `exists`, `add`, `put(key, value)`, `delete`, `findRecords`,
  `findRecordKeys`, `count`, `deleteRecords`, `index(ref)`.
  `db.inTransaction(stores: [...], mode: ..., run: (txn) ...)` is the generic
  form (mode defaults to read-only).
* The callback's return value is the transaction's result. Any thrown error
  aborts and rolls back. Do not catch inside; let it propagate.
* Do not await anything but SDB calls inside the callback (no network, no
  `Future.delayed`, no lock): the underlying IndexedDB transaction commits as
  soon as no request is pending and later calls fail. Prepare data first.
* Writes need `SdbTransactionMode.readWrite`; reads through the database
  without an explicit transaction are fine.

### Iterating, watching, changes

* `store.iterate(client, {mode, options, onRow})` walks a cursor; `onRow`
  gets a `SdbCursorRow` and returns `true` to continue, `false` to stop
  (may be async). Pass `mode: SdbTransactionMode.readWrite` to call
  `row.update(newValue)`, which replaces the whole value at the cursor
  position; the row itself exposes nothing else, so select the rows with
  `options` (boundaries, filter, offset, limit). `index.iterate` does the
  same with `SdbIndexCursorRow`. Prefer `findRecords`/`streamRecords` for
  reads.
* `store.onSnapshots(db, {options})`, `index.onSnapshots(db, {options})`,
  `store.record(key).onSnapshot(db)`, `index.record(k).onSnapshot(db)` and
  `store.onCount(db)` / `index.onCount(db)` are streams that emit now and
  after every change (including other browser tabs on the web). Cancel the
  subscription when done.
* `store.addOnChangesListener(db, (txn, changes) {...})` runs inside the
  writing transaction with `List<SdbRecordChange>` (`isAdd`, `isUpdate`,
  `isDelete`, `oldValue`, `newValue`, `ref`); pair with
  `removeOnChangesListener(db, sameCallback)`. Costly: use for derived data,
  not for UI.

### Joining two stores

* `store.joinIterate(client, {required target, joinKeyPath, mode, options,
  joinOptions, onRow})` walks the records of `store` together with the records
  they reference, the equivalent of an sql `LEFT JOIN`. `index.joinIterate`
  does the same from an index, in index key order. Both read the joined
  records once per distinct join key, not once per row.
* The join key is the value at `joinKeyPath` in the source value (dot
  separated for a nested field), the source primary key when `joinKeyPath` is
  null, or the index key when joining from an index.
* `target` is one required `SdbJoinTarget`: `otherStore.asJoinTarget` matches
  the key against a primary key (at most one record),
  `otherIndex.asJoinTarget` against an index key (any number, a source record
  then giving one row per match). Exactly one of the two, by construction.
* `options` is the usual `SdbFindOptions` on the iterated side;
  `joinOptions` is a separate `SdbJoinFindOptions` (`distinct`, `inner`,
  `chunkSize`). `offset`/`limit` apply to what is handed out, i.e. **after**
  `inner` and `distinct` dropped any row, like an sql `LIMIT`.
* Pick the shape by what you need, each one only reads that:
  `joinIterate`/`findJoinRows` for both sides (`SdbJoinRow.record` is never
  null, `joinedRecord` is null on a left join);
  `joinIterateRecords`/`findJoinRecords` for the source records, one per
  source record (with `inner: true`, a semi join);
  `joinIterateJoinedRecords`/`findJoinedRecords` for the referenced records,
  always inner so never null; `joinCount` for the row count.
* **Index the join key path and join from that index**: the index key is then
  the join key, so an implementation able to join natively (`idb_sqflite`
  turns a join into one sql `LEFT JOIN` per chunk) reads it straight from the
  index instead of parsing every stored value.
* The iteration runs in one transaction covering both stores; pass a
  transaction instead of the database to join inside an existing one. Same
  rule as any transaction: no lengthy async work in the callback.

## Examples

### App database class with schema and index

```dart
import 'package:idb_shim/sdb.dart';

class LibraryDb {
  final books = SdbStoreRef<int, SdbModel>('books');
  final authors = SdbStoreRef<String, SdbModel>('authors');
  late final booksByAuthor = books.index<String>('author');
  late final booksByAuthorYear = books.index2<String, int>('author_year');

  late final schema = SdbDatabaseSchema(stores: [
    books.schema(autoIncrement: true, indexes: [
      booksByAuthor.schema(keyPath: 'author'),
      booksByAuthorYear.schema(keyPath: ['author', 'year']),
    ]),
    authors.schema(),
  ]);

  Future<SdbDatabase> open(SdbFactory factory, String name) =>
      factory.openDatabase(name,
          options: SdbOpenDatabaseOptions(version: 1, schema: schema));
}
```

### CRUD on records

```dart
import 'package:idb_shim/sdb.dart';

final books = SdbStoreRef<int, SdbModel>('books');
final authors = SdbStoreRef<String, SdbModel>('authors');

Future<void> crud(SdbDatabase db) async {
  // String key store: choose the key.
  await authors.record('tolkien').put(db, {'name': 'J.R.R. Tolkien'});
  // int autoIncrement store: the key is generated.
  final key = await books.add(db, {'title': 'The Hobbit', 'author': 'tolkien', 'year': 1937});

  final snapshot = await books.record(key).get(db);
  print('${snapshot?.key}: ${snapshot?.value}');
  final title = (await books.record(key).getValue(db))?['title'];
  print(title);

  await books.record(key).put(db, {'title': 'The Hobbit', 'author': 'tolkien', 'year': 1937, 'read': true});
  print(await books.record(key).exists(db)); // true
  await books.record(key).delete(db);
  print(await books.count(db)); // 0
}
```

### Queries with boundaries, filters and indexes

```dart
import 'package:idb_shim/sdb.dart';

final books = SdbStoreRef<int, SdbModel>('books');
final booksByAuthor = books.index<String>('author');
final booksByAuthorYear = books.index2<String, int>('author_year');

Future<void> queries(SdbDatabase db) async {
  // Primary key range: keys 10 <= key < 20, newest first, 5 max.
  final page = await books.findRecords(db,
      boundaries: SdbBoundaries.values(10, 20), descending: true, limit: 5);
  for (final record in page) {
    print('${record.key} ${record.value['title']}');
  }

  // Index: every book of an author, then a composite range.
  final tolkien = await booksByAuthor.record('tolkien').findRecords(db);
  print(tolkien.values);
  final early = await booksByAuthorYear.findRecords(db,
      boundaries: SdbBoundaries.values(('tolkien', 0), ('tolkien', 1950)));
  print(early.map((r) => r.indexKey.$2));

  // In-memory filter combined with an index key.
  final unread = await booksByAuthor.findRecords(db,
      boundaries: SdbBoundaries.key('tolkien'),
      filter: SdbFilter.notEquals('read', true));
  print(unread.length);

  // Same query through options.
  final first = await books.findRecord(db,
      options: SdbFindOptions(filter: SdbFilter.matches('title', '^The')));
  print(first?.value);
  print(await books.count(db, boundaries: SdbBoundaries.lowerValue(100)));
}
```

### Transactions on one or several stores

```dart
import 'package:idb_shim/sdb.dart';

final books = SdbStoreRef<int, SdbModel>('books');
final stats = SdbStoreRef<String, SdbModel>('stats');

Future<int> importBooks(SdbDatabase db, List<SdbModel> items) {
  return db.inStoreTransaction(books, SdbTransactionMode.readWrite, (txn) async {
    var added = 0;
    for (final item in items) {
      await books.add(txn, item);
      added++;
    }
    return added; // the transaction result
  });
}

Future<void> addAndCount(SdbDatabase db, SdbModel book) {
  return db.inStoresTransaction([books, stats], SdbTransactionMode.readWrite,
      (txn) async {
    await txn.store(books).add(book);
    final current = await stats.record('books').getValue(txn);
    final count = (current?['count'] as int? ?? 0) + 1;
    await stats.record('books').put(txn, {'count': count});
  });
}
```

### Cursor iteration and in-place migration

```dart
import 'package:idb_shim/sdb.dart';

final books = SdbStoreRef<int, SdbModel>('books');

/// Archive every book of an author without loading the store in memory.
Future<int> archiveAuthor(SdbDatabase db, String author) async {
  var archived = 0;
  await books.iterate(db,
      mode: SdbTransactionMode.readWrite,
      options: SdbFindOptions(filter: SdbFilter.equals('author', author)),
      onRow: (row) async {
    // update() replaces the whole value at the cursor position.
    await row.update({'author': author, 'archived': true});
    archived++;
    return true;
  });
  return archived;
}

/// Stop early: is there at least one unread book?
Future<bool> hasUnread(SdbDatabase db) async {
  var found = false;
  await books.iterate(db,
      options: SdbFindOptions(filter: SdbFilter.notEquals('read', true)),
      onRow: (row) {
    found = true;
    return false; // stop
  });
  return found;
}

/// Read-modify-write: stream snapshots and update through the record ref.
Future<void> markAllRead(SdbDatabase db) {
  return db.inStoreTransaction(books, SdbTransactionMode.readWrite, (txn) async {
    final snapshots = await books.findRecords(txn);
    for (final snapshot in snapshots) {
      await snapshot.ref.put(txn, {...snapshot.value, 'read': true});
    }
  });
}
```

### Joining books with their author

```dart
import 'package:idb_shim/sdb.dart';

final authorStore = SdbStoreRef<int, SdbModel>('author');
final bookStore = SdbStoreRef<int, SdbModel>('book');
// A book value looks like {'title': 't1', 'authorId': 1}.
// Index the join key path: the join then reads the key from the index.
final bookAuthorIndex = bookStore.index<int>('authorId');

final schema = SdbDatabaseSchema(
  stores: [
    authorStore.schema(),
    bookStore.schema(
      indexes: [bookAuthorIndex.schema(keyPath: 'authorId')],
    ),
  ],
);

/// Every book with its author, `null` when it has none (left join).
Future<void> listBooks(SdbDatabase db) async {
  await bookStore.joinIterate<int, SdbModel>(
    db,
    target: authorStore.asJoinTarget,
    joinKeyPath: 'authorId',
    onRow: (row) {
      // row.record is never null, row.joinedRecord is on a left join.
      print('${row.record.value['title']} by '
          '${row.joinedRecord?.value['name'] ?? 'unknown'}');
      return true; // false stops early
    },
  );
}

/// The same, from the index: same pairing, the join key read off the index.
/// Books with no `authorId` are not in the index, so they do not show up.
Future<List<SdbJoinRow<int, SdbModel, int, SdbModel>>> booksWithAuthor(
  SdbDatabase db,
) => bookAuthorIndex.findJoinRows<int, SdbModel>(
  db,
  target: authorStore.asJoinTarget,
  joinOptions: const SdbJoinFindOptions(inner: true),
);

/// One side only, never null, the other side not even read.
Future<void> oneSided(SdbDatabase db) async {
  // The books that do have an existing author (a semi join).
  final withAuthor = await bookStore.findJoinRecords<int, SdbModel>(
    db,
    target: authorStore.asJoinTarget,
    joinKeyPath: 'authorId',
    joinOptions: const SdbJoinFindOptions(inner: true),
  );
  // The authors actually referenced by a book, each one once.
  final authors = await bookStore.findJoinedRecords<int, SdbModel>(
    db,
    target: authorStore.asJoinTarget,
    joinKeyPath: 'authorId',
    joinOptions: const SdbJoinFindOptions(distinct: true),
  );
  print('${withAuthor.length} books, ${authors.length} authors');
}

/// One to many, from the parent side: each author with each of their books.
/// An author with three books gives three rows, one with none gives one row
/// with a null joinedRecord.
Future<void> authorsWithBooks(SdbDatabase db) async {
  await authorStore.joinIterate<int, SdbModel>(
    db,
    target: bookAuthorIndex.asJoinTarget,
    // No joinKeyPath: the author primary key is the join key.
    onRow: (row) => true,
  );
}
```

### Live updates in the UI

```dart
import 'dart:async';
import 'package:idb_shim/sdb.dart';

final books = SdbStoreRef<int, SdbModel>('books');

StreamSubscription<List<SdbRecordSnapshot<int, SdbModel>>> watchRecent(
    SdbDatabase db, void Function(List<SdbModel> values) onData) {
  return books
      .onSnapshots(db, options: SdbFindOptions(descending: true, limit: 20))
      .listen((snapshots) => onData(snapshots.values));
}

Stream<SdbModel?> watchBook(SdbDatabase db, int key) =>
    books.record(key).onSnapshot(db).map((snapshot) => snapshot?.value);
```

### Unit test with an isolated memory factory

```dart
import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';

final items = SdbStoreRef<int, SdbModel>('items');

void main() {
  late SdbFactory factory;
  setUp(() => factory = newSdbFactoryMemory());

  test('add and find', () async {
    final db = await factory.openDatabase('t.db',
        options: SdbOpenDatabaseOptions(
            version: 1,
            schema: SdbDatabaseSchema(stores: [items.schema(autoIncrement: true)])));
    await items.add(db, {'name': 'a'});
    await items.add(db, {'name': 'b'});
    expect((await items.findRecords(db)).values.map((v) => v['name']), ['a', 'b']);
    await db.close();
  });
}
```

## Common mistakes

* Declaring a store as `SdbStoreRef<int, Map>` or with a key type other than
  `int`/`String`; use `SdbModel` and check the key type.
* Removing a store or index from `SdbDatabaseSchema` without meaning it: the
  next version upgrade deletes it and its data.
* Changing an index key path or a store key path in place; create a new
  store/index (new name) and migrate in `onVersionChange`.
* Using `store.put(db, value)` on a store without `keyPath`; use
  `store.record(key).put(db, value)` or `add`.
* Relying on `filter` alone for a large store; add `boundaries` or an index.
* Awaiting network or timers inside `inStoreTransaction`.
* Catching the unique-constraint error inside a transaction instead of
  checking existence first.
* Using `sdbFactoryIo` in a Flutter app instead of `sdbFactorySqflite`.
* Joining on a field of the **target** store that is neither its primary key
  nor an index: there is no such option, because it would mean a full scan of
  the target per join key. Index that field and use `index.asJoinTarget`.
* Expecting `offset`/`limit` on a join to count source records: they count
  what is handed out, after `inner` and `distinct`.
* Reaching for the rows when you only need one side: prefer
  `findJoinRecords`/`findJoinedRecords`, which hand out plain records and do
  not read the other side.

## More

The full join documentation, including the native (sql) path and how the join
key is read, is in
[doc/sdb_join.md](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/sdb_join.md).

See [references/advanced.md](references/advanced.md) for `SdbOpenDatabase`
manual migrations, `SdbCodec`, `SdbTimestamp`/`SdbBlob` details, sandboxing
(`sandbox(path:)`), the debug logger (`debugWrapInLogger`), export/import
(`sdbExportDatabaseLines`, `sdbImportDatabase`), the raw idb escape hatches
and the timestamp format migration helper.
