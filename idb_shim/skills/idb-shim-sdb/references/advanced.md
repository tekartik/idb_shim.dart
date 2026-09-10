# idb_shim SDB advanced topics

Everything is exported by `package:idb_shim/sdb.dart` unless stated otherwise.

## Manual migrations in onVersionChange

`SdbOpenDatabaseOptions.onVersionChange` receives a `SdbVersionChangeEvent`
with `oldVersion` (0 for a new database), `newVersion`, `db`
(`SdbOpenDatabase`) and `transaction` (`SdbOpenTransaction`, a normal
`SdbTransaction` usable with every store/record method). When a `schema` is
also given, the callback runs after the schema has been applied: use it for
data fix-ups, not for structure.

```dart
final books = SdbStoreRef<int, SdbModel>('books');
final bySerial = books.index<String>('serial');
final byTypeId = books.index2<String, int>('type_id');

Future<SdbDatabase> open(SdbFactory factory) => factory.openDatabase('lib.db',
    options: SdbOpenDatabaseOptions(
      version: 3,
      onVersionChange: (event) async {
        final db = event.db;
        if (event.oldVersion < 1) {
          db.createStore(books, autoIncrement: true);
        }
        if (event.oldVersion < 2) {
          db.objectStore(books).createIndex(bySerial, 'serial', unique: true);
        }
        if (event.oldVersion < 3) {
          final store = db.objectStore(books);
          store.createIndex2(byTypeId, 'type', 'id');
          // Data fix-up inside the upgrade transaction.
          final txn = event.transaction;
          for (final snapshot in await books.findRecords(txn)) {
            await snapshot.ref.put(txn, {...snapshot.value, 'type': 'book'});
          }
        }
      },
    ));
```

`SdbOpenDatabase`: `createStore(ref, {keyPath, autoIncrement})` (single
`String` key path only; `autoIncrement` defaults to true for `int` keys),
`objectStore(ref)`, `deleteStore(name)`, `objectStoreNames`.
`SdbOpenStoreRef`: `createIndex(ref, keyPath, {unique})` where `keyPath` is a
`String`, a `List<String>` or a `SdbKeyPath`; `createIndex1..4`;
`deleteIndex(name)`; plus the read/write methods of a transaction store.

## Schema objects

* `SdbDatabaseSchema(stores: [...])`, `store.schema({keyPath: SdbKeyPath?,
  autoIncrement, indexes})`, `index.schema({keyPath, unique})`,
  `index1Ref.schema1(path)`, `index2Ref.schema2(p1, p2)`, `schema3`,
  `schema4`. `SdbKeyPath.single('id')` / `SdbKeyPath.multi(['a', 'b'])`.
* `schema.storeNames`, `schema.storeRefs`, `schema.def` (a comparable
  `SdbDatabaseSchemaDef` with `toDebugMap()`), `storeSchema.indexNames`.
* `db.openDatabaseOptions` returns the options used to open (null when the
  database was opened without options). `db.readSchemaDef()` reads the actual
  structure (requires an open with a schema).
* Store key path: `SdbTransactionStoreRef.keyPath` (`SdbKeyPath?`),
  `autoIncrement`, `indexNames`; index: `SdbTransactionIndexRef.keyPath`,
  `unique`, `multiEntry` (via `txn.store(ref).index(indexRef)`).

## Codec, timestamps, blobs

* `SdbCodec.defaultCodec` (default) encodes `SdbTimestamp` and `SdbBlob`
  inside values and index keys so they round-trip on every backend.
  `SdbCodec.none` stores values as is (only `bool`, `num`, `String`, `List`,
  `Map`). Set it with `SdbOpenDatabaseOptions(codec: ...)`.
* `SdbTimestamp` is `package:sembast` `Timestamp`: `SdbTimestamp(seconds,
  nanoseconds)`, `SdbTimestamp.now()`, `SdbTimestamp.fromDateTime(dt)`,
  `SdbTimestamp.fromMillisecondsSinceEpoch(ms)`, `SdbTimestamp.parse(iso)`,
  `toDateTime({isUtc})`, `toIso8601String()`, `compareTo`; extension
  `TekartikSembastTimestampExt` adds `difference(other)`, `addDuration(d)`,
  `substractDuration(d)`. It is an allowed index key type
  (`store.index<SdbTimestamp>('created')`).
* `SdbBlob` is sembast `Blob`: `SdbBlob(Uint8List bytes)`, `bytes`,
  `SdbBlob.fromBase64(text)`. `Uint8List` values are also accepted directly.
* Databases created before idb_shim 2.9.0 store timestamps in an older
  format; `client.compatMigrate1To2({stores})` (experimental extension
  `SdbClientMigrationExtension`) rewrites them in place.

## Find options

`SdbFindOptions<K>({boundaries, filter, limit, offset, descending})` with
`copyWith(...)`; `sdbFindOptionsMerge(options, {boundaries, limit, offset,
descending, filter})` builds one from loose parameters (options win when
given). `SdbBoundaries.toConditionString()` prints `0 <= ? < 1` for
debugging. Offset and limit are applied natively by backends that can (SQL
`LIMIT`/`OFFSET` with `idb_sqflite`), by cursor otherwise; a filter is always
applied in memory before offset/limit.

## Filters (`SdbFilter` = sembast `Filter`)

`SdbFilter.equals(field, value, {anyInList})`, `notEquals`, `isNull`,
`notNull`, `lessThan`, `lessThanOrEquals`, `greaterThan`,
`greaterThanOrEquals`, `inList(field, list)`, `matches(field, regexpString)`,
`matchesRegExp`, `arrayContains`, `arrayContainsAll`, `arrayContainsAny`,
`and([...])`, `or([...])`, `not(filter)`, `custom((SdbFilterRecordSnapshot
record) => bool)`. Field names may use dotted paths (`'address.city'`).
Inside `custom`, `record.value`, `record.key` and, with
`SdbFilterRecordSnapshotExt`, `record.primaryKey` / `record.indexKey`.

## Sandboxing, paths, logger

* `factory.sandbox(path: 'dir')` (`SdbFactorySandboxExtension`) returns a
  `SdbFactory` whose databases all live below `dir` in the original factory;
  escaping with `..` throws `ArgumentError`. `factory.pathContext` is the
  `package:path` context, `factory.getDatabaseFullPath(name)` the resolved
  name (debugging).
* `factory.debugWrapInLogger({type: SdbFactoryLoggerType.all, maxLogCount})`
  prints every idb call. It is annotated `@doNotSubmit`: remove before
  committing.
* `factory.name` and `db.factory` identify the backend; `factory.idbFactory`
  is the underlying classic factory (`persistent`, `name`).

## Export and import (`package:idb_shim/utils/sdb_import_export.dart`)

* `sdbExportDatabaseLines(db)` returns the sembast line export
  (`List<Object>`) of an `SdbDatabase`, whatever the backend.
* `sdbImportDatabase(data, dstFactory, dstName, {codec})` imports lines or a
  map export into `dstFactory` and returns the opened `SdbDatabase`.

## Escape hatches to the classic API

* `sdbFactoryFromIdb(idbFactory)` builds a `SdbFactory` on any `IdbFactory`
  (memory, io, web, `idb_sqflite`, logger, sandbox); `factory.idbFactory`
  goes back.
* `db.rawIdb` (`SdbDatabaseIdbExt`, `@visibleForTesting`) is the classic
  `Database` behind an `SdbDatabase`, for a test that needs a raw cursor or
  `objectStoreNames`.
* Store key paths are exposed as `Object?` on `SdbTransactionStoreRef` via
  `keyPath` and on the classic store through `rawIdb`.

## Cross-tab notifications (web)

On the web, `onSnapshot`/`onSnapshots`/`onCount` streams also refresh when
another tab writes to the same store (idb_shim 2.9.2+). In-process
`addOnChangesListener` callbacks only see the current isolate's transactions.
