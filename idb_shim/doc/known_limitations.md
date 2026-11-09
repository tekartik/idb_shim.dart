# Known limitations

## sembast implementation (io and memory)

The io (`idbFactorySembastIo`) and memory (`idbFactoryMemory`) factories run
IndexedDB on top of [sembast](https://pub.dev/packages/sembast):

* A cursor walks the records read when it was opened: records added, changed
  or deleted by other requests of the same transaction while it runs are not
  seen (`cursor.update()` and `cursor.delete()` are).
* The `nextunique` and `prevunique` cursor directions are not supported.
* `Cursor.source` is not supported.
* There is no other connection to block: `onBlocked` and
  `Database.onVersionChange` never fire, an upgrade always runs.
* Two `open()` of the same database share one sembast database: closing one
  closes the other.
* With `autoIncrement`, a key given explicitly must be an int to be taken
  into account by the key generator.
* A database file is for a single process: use
  [`idb_sqflite`](https://pub.dev/packages/idb_sqflite) when several
  processes (or isolates) open it.

## Web

* Errors are DOM exceptions, wrapped in a `DatabaseError`.
* The values are converted with a custom encoder (`DateTime` included, which
  Firefox does not store natively), to be the same as on the other platforms.

## Older browsers

Kept for reference, these browsers are no longer tested.

IE 11, Edge 12:

* no support for reading the `objectStore.autoIncrement` property
* `ObjectStore.count()` without argument throws a `DataError` exception
* the transaction is closed sooner than in Chrome or Firefox: calling a
  function that wraps an idb call can terminate it
* `IDBIndex.multiEntry` is not supported

Safari 9:

* no support for transactions on multiple stores (idb_shim simulates them
  with one transaction per store, without abort)
* very short transaction life cycle
