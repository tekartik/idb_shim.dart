# idb_shim advanced helpers

All import paths are given per section. Everything works with any
`IdbFactory` (web, sembast io, memory, `idb_sqflite`) unless stated otherwise.

## Sandboxing a factory (`package:idb_shim/idb_shim.dart`)

`factory.sandbox(path: 'some/dir')` (extension `IdbFactorySandboxExtension`)
returns an `IdbFactory` where every database name is resolved below `path`
in the original factory. Escaping the root (`../other.db`) throws
`ArgumentError`. Sandboxing a sandbox flattens to a single level. Use it to
isolate tests, users or app flavours sharing one backend.

```dart
var sandboxed = newIdbFactoryMemory().sandbox(path: 'user1');
var db = await sandboxed.open('data.db', version: 1,
    onUpgradeNeeded: (e) => e.database.createObjectStore('s'));
// Same database from the parent: open('user1/data.db').
print(await sandboxed.getDatabaseFullPath('data.db')); // user1/data.db
```

`factory.getDatabaseFullPath(name)` (debugging) and `factory.pathContext`
(a `package:path` `Context`, used for the name/path arithmetic) exist on every
factory. `IdbFactorySandbox` is the interface of the returned factory
(`delegatePath(path)`).

## Debug logger (`package:idb_shim/idb_client_logger.dart`)

`getIdbFactoryLogger(factory, {type: IdbFactoryLoggerType.all})` wraps a
factory in an `IdbFactoryLogger` that prints every open, transaction and
request with an id. `IdbFactoryLogger.debugMaxLogCount` caps the output
globally. The shortcut `factory.debugWrapInLogger({type, maxLogCount})`
(`IdbFactoryLoggerDebugExt`, exported by `idb.dart`) is marked `@Deprecated`
on purpose so that it does not survive in committed code.

## Downgrade-safe open (`package:idb_shim/idb.dart`)

`factory.openOnDowngradeDelete(name, {version, onUpgradeNeeded, onBlocked})`
(`IdbFactoryExt`) tries `open`; on failure it opens without a version, and if
the stored version is higher than `version` it deletes the database and opens
again. Development convenience only.

## Copying databases (`package:idb_shim/utils/idb_utils.dart`)

* `copySchema(srcDb, dstFactory, dstName)` deletes `dstName` in `dstFactory`
  and re-creates the stores and indexes of `srcDb` at the same version;
  returns the opened destination.
* `copyStore(srcDb, srcStoreName, dstDb, dstStoreName)` clears the
  destination store and copies every record (values are held in memory).
* `copyDatabase(srcDb, dstFactory, dstName)` does both for every store. Use
  it to move data between backends (memory to io, io to web...).
* List helpers for auto-advance cursor streams: `cursorToList(stream,
  [offset, limit, matcher])`, `idbCursorToList(stream, {offset, limit})`,
  `keyCursorToList`, `cursorToKeyList`, `cursorToPrimaryKeyList`. Open the
  cursor with `autoAdvance: true` for these (unlike the
  `idb_cursor_utils.dart` stream extensions, which drive the cursor).

## Export and import (`package:idb_shim/utils/idb_import_export.dart`)

Sembast export format, usable for backups and fixtures:

* `idbExportDatabase(db)` returns a `Map<String, Object?>`;
  `idbExportDatabaseLines(db)` returns a `List<Object>` (one line per
  record, better for large data). Non-sembast databases are copied to a
  temporary memory database first.
* `idbImportDatabase(data, dstFactory, dstName)` accepts either format and
  returns the opened `Database`.
* `sdbExportDatabase`/`sdbImportDatabase` here are deprecated aliases; the
  SDB typed versions live in `package:idb_shim/utils/sdb_import_export.dart`.

## Sembast bridge (`package:idb_shim/idb_client_sembast.dart`)

`IdbFactorySembast(sembastDatabaseFactory, [path])` builds an `IdbFactory` on
any sembast `DatabaseFactory` (io, memory, custom). `idbFactorySembastMemory`
is the shared memory instance. On such a factory:

* `sembastFactory` (alias `sdbFactory`) is the underlying sembast factory.
* `getSembastDatabase(db)` / `getSdbDatabase(db)` return the sembast
  `Database` behind an idb `Database`.
* `openFromSembastDatabase(sembastDb)` / `openFromSdbDatabase` wrap an
  already opened sembast database.
* `getDbPath(dbName)` gives the sembast file path.

Do not use these on the web or with `idb_sqflite`; check
`factory is IdbFactorySembast` first.

## Native web extras (`package:idb_shim/idb_client_native.dart`)

* `idbFactoryWebSupported` / `idbFactoryWebWorkerSupported` are true when
  IndexedDB exists in the current context; `idbFactoryWeb` /
  `idbFactoryWebWorker` throw when it does not.
* `idbFactoryFromIndexedDB(nativeIdbFactory)` wraps a raw `IDBFactory` JS
  object (for example `self.indexedDB` in a worker).
* The database is bound to the origin, including the port: use the same
  port when debugging or the data "disappears".

## Backend limitations (sembast io / memory)

* Cursor directions `nextunique`/`prevunique` are not supported.
* `Cursor.source` is not available.
* `Index.get` supports a key, not a `KeyRange`.
* `onBlocked` is not raised; other connections get errors on their next
  call instead.
* With `autoIncrement`, an explicit key must be an int.

## Value and key types

* Keys: `int`, `double`, `String` (and lists of them for composite indexes).
  `IdbFactory.cmp(a, b)` compares two keys with IndexedDB ordering.
* Values: `num`, `String`, `bool`, `List`, `Map`, `DateTime`, `Uint8List`.
  No `null` value, no cycles. Large doubles are not turned into ints by the
  sembast backends (the browser does).
* Firefox does not store `DateTime` natively; idb_shim encodes it itself on
  the web, so the value is portable between backends.
* `IdbValueMapExt` (`package:idb_shim/utils/idb_value_utils.dart`) and
  `package:idb_shim/utils/idb_cursor_utils.dart` (`CursorRow`, `KeyCursorRow`,
  `IdbCursorRowIterableExt.values`) help converting read values.

## Error types (`package:idb_shim/idb.dart`)

`DatabaseError` (an `Error` with `message`) and its subclasses
`DatabaseReadOnlyError`, `DatabaseStoreNotFoundError`,
`DatabaseIndexNotFoundError`, `DatabaseTransactionStoreNotFoundError`,
`DatabaseNoKeyError`, `DatabaseInvalidKeyError`; `DatabaseException` (an
`Exception`) for other failures. Native DOM exceptions are converted to
`DatabaseError` with the DOM message text (for example
`ConstraintError: ...` on a duplicate `add`).
