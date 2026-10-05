## 2.9.11-1

* sdb: the implementation is pluggable. A backend that is not IndexedDB
  implements the internal interfaces (`SdbDatabaseInterface`,
  `SdbTransactionInterface`, `SdbTransactionStoreRefInterface`,
  `SdbTransactionIndexRefInterface`, `SdbOpenStoreRefInterface`) and the
  default mixins exported by `src/sdb/sdb_mixin.dart`; the public API, joins,
  change listeners, `onSnapshot` and the schema helpers dispatch through them.
  The idb implementation is unchanged.
* sdb: `sdbExportDatabaseLines` and `sdbImportDatabase` work with any sdb
  factory, same lines format (DateTime and Uint8List exported as `@Timestamp`
  and `@Blob`).
* sdb: `compatMigrate1To2` awaits its row updates.
* idb_test: `sdbDefineAllTests(SdbTestContext)` runs the whole sdb suite on any
  `SdbFactory`.

## 2.9.10

* sdb: the version change requests of the other connections (another tab,
  an iframe, the same page), the IndexedDB `versionchange` and `blocked`
  events, on `SdbOpenDatabaseOptions`:
  * `versionChangeAction` (`SdbVersionChangeAction`, `close` by default):
    what the database does on its own when another connection opens it at a
    higher version or deletes it: `none` (stay open, the other waits),
    `close` (the other open completes instead of staying blocked forever,
    `SdbDatabase.isClosed` tells), `closeAndReload` and
    `closeAlertAndReload` (web: the page reloads on the new version);
  * `onVersionChangeRequest`: called first, with the current and the
    requested version (null on a delete), to save what must be or tell the
    user your own way;
  * `blockedAction` (`SdbBlockedAction`, `alert` by default): what the open
    does on its own while a connection that keeps the database open at a
    lower version (a tab of an older app) blocks it: a "close the other
    tabs" alert on the web, or `none`; `onBlocked` is called first. The open
    completes once that connection closes.
* `VersionChangeEvent.newVersionOrNull` (null on a delete); the native
  `Database.onVersionChange` stream delivers synchronously, so a close in the
  handler happens inside the browser event; the sembast one is an empty
  stream instead of throwing.
* Example `example/sdb_version_change_exp`: two frames of one app opening the
  same database at different versions.

## 2.9.10-1

* sdb: Add join support, walking the records of a store (or of an index)
  together with the records they reference in another store, the equivalent of
  an sql `LEFT JOIN`. On `SdbStoreRef` and `SdbIndexRef`:
  * `joinIterate`/`findJoinRows` hand out `SdbJoinRow` (both sides),
  * `joinIterateRecords`/`findJoinRecords` the source records only, one per
    source record,
  * `joinIterateJoinedRecords`/`findJoinedRecords` the referenced records only
    (always inner, so never null),
  * `joinCount` the number of rows.
* sdb: `SdbJoinTarget` says what the join key is matched against, a store (on
  its primary key) or an index (on its index key), exactly one of the two:
  `authorStore.asJoinTarget`, `authorEmailIndex.asJoinTarget`.
* sdb: `SdbJoinFindOptions` (`distinct`, `inner`, `chunkSize`) holds the join
  specific options, next to the usual `SdbFindOptions` on the iterated side;
  every join method takes both.
* sdb: A join is resolved natively when the implementation supports it
  (`idb_sqflite` turns it into a single sql `LEFT JOIN`/`INNER JOIN` per
  chunk, with the key range, `inner`, offset and limit pushed down), and by
  walking a cursor otherwise; both hand out the same rows in the same order.
* Internal (not part of the public idb API): `IdbJoinQuerySupport`,
  implemented by an `ObjectStore`/`Index` implementation able to join natively.
* Internal: `SdbIndexCursorRow` now exposes `indexKey` and `primaryKey`.

## 2.9.9

* Add `idb-shim-database` and `idb-shim-sdb` agent skills in `skills/`, installable with `dart run skills@ get`

## 2.9.8

* sdb: Apply the offset and the limit natively (sql `LIMIT`/`OFFSET`) instead of
  walking a cursor, when the implementation supports it, for `findRecords`,
  `findRecordKeys`, `streamRecords`, `iterate` and `delete` on stores and indexes.
  An implementation reading its rows in one go would otherwise read the whole
  store on every paged query.
* sdb fix: `iterate` was ignoring the offset, the skipped rows were handed to the
  handler.
* Internal (not part of the public idb API): `IdbPagedQuerySupport`, implemented
  by an `ObjectStore`/`Index` implementation able to page natively.

## 2.9.7+1

* fix: correct count logic in sdb_index and sdb_transaction_store

## 2.9.7

* Expose `IdbFactorySandbox` and `SdbFactorySandbox`

## 2.9.6+2

* Add `getDatabaseFullPath()` extension method on `IdbFactory` and `SdbFactory`
* Deprecate `fullPath`
* export `SdbDatabase.openDatabaseOptions`
* export `SdbTimestamp` helpers (`difference`, `addDuration`, `substractDuration`)

## 2.9.5

* Add `fullPath()` extension method on `IdbFactory` and `SdbFactory` to get the full
  path of a database. 
* Add `pathContext` method to `IdbFactory` and extension method to `SdbFactory`

## 2.9.4

* Add `sandbox()` extension method on `IdbFactory` and `SdbFactory` to create
  a factory where every database is located below a given path.

## 2.9.3+1

* Requires dart 3.12
* Add `onCount` for stores and indexes

## 2.9.2

* sdb: Add `iterate` on Store and Cursor.
* sdb: Add cross tab synchronization on the web

## 2.9.1

* sdb: Allow raw data and codec support

## 2.9.0

* sdb: Add support for `SdbTimestamp` in index
* sdb: new internal format for timestamp, migration with helper

## 2.8.5+2

* sdb: Add `onSnapshot` and `onSnapshots` support for stores, records, and indexes.

## 2.8.4+1

* sdb: Allow both `schema` and `onVersionChange` in open options
* sdb: deprecate params `version`, `schema`, `onVersionChanged` on `SdbFactory.openDatabase` and prefer open options
* sdb: fix `onVersionChange` transaction, allowing manipulating data during open

## 2.8.3

* Add built-in `SdbTimestamp` and `SdbBlob` to Sdb database

## 2.8.2+4

* Add onChange listener to SdbDatabase
* Add sdb import/export helpers
* Add options to `SdbFactory.openDatabaseOnDowngradeDelete` to support schema.

## 2.8.1

* Import jdb support (from sembast_web)

## 2.7.1+2

* Supports Sdb schema and improve sdb api
* Refactor sembast transaction implementation
* Add find options to all queries
* Experimental record streaming in Sdb

## 2.7.0

* Requires dart 3.10
* Supports opening a database with either `version` or `unUpgadeNeeded` specified

## 2.6.7+1

* Requires dart 3.8
* export extra sdb mixin

## 2.6.6+2

* sdb:
  * Add `bool? descending` argument to all Sdb store and index APIs.
  * Export `SdbKey`, `SdbValue`, `SdbIndexKey`, `SdbClient`.
  * Export `SdbOpenIndexRef`

## 2.6.5+1

* Add `openOnDowngradeDelete` to `IdbFactory` to handle downgrade by deleting the database.
* Add `openDatabaseOnDowngradeDelete` to `SdbFactory` to handle downgrade by deleting the database.

## 2.6.4+1

* Add Web worker support (`idbFactoryWebWorker`)

## 2.6.3+2

* Open Sdb to other implementation and add filtering support

## 2.6.2

* Requires dart 3.7

## 2.6.1+7

* Requires dart 3.5

## 2.6.0+5

* More support for sdb, including key on 2,3 and 4 fields, and more.
* Add `idbFactoryWeb` (shortcut for `idbFactoryNative`)

## 2.5.0+3

* Remove legacy `dart:html` implementation.
* Remove `dev_test` dependency

## 2.4.1+4

* Add simple sdb opinionated strong typed api based on idb database.
* Complete dart2wasm compilation support
* Deprecate old idbFactoryNative.

## 2.4.0

* Add new native implementation based on new js_interop and web package.
* Allow wasm compilation for web support (legacy implementation is still available for now by importing explicitly `idb_shim_client_native_html.dart`)

## 2.3.2

* Add new cursor stream extension in `utils/idb_cursor_utils.dart` to convert a stream to a list 
  that supports offset and limit.

## 2.3.1

* Dart 3 support

## 2.3.0+2

* Support strict-casts mode.

## 2.2.0+8

* Fix keyPath array index creation
* mimic Chrome and prevent cursor delete when using openKeyCursor and invalid KeyRange
* composite key support: allow keyPath as List<String> in createObjectStore 
* add `cursorToPrimaryKeyList()` and `cursorToKeyList` utility in idb_utils

## 2.1.0

* Fix io implementation for generated key internal storage
* Requires dart 2.18+

## 2.0.1+1

* New lint supports
* Requires dart 2.14+

## 2.0.0+2

* `nnbd` supports, breaking change.
* No longer supports `null` for record value.
* Remove deprecated methods.

## 1.12.2+3

* Add support for `Transaction.abort`
* Allow read/write during open transaction.

## 1.12.1+1

* Add `ObjectStore.getAll/getAllKeys` and `Index.getAll/getAllKeys`
* Fix import/export through sembast

## 1.11.1+1

* Export `idbFactoryNative`, `idbFactoryMemory` and `idbFactoryMemoryFs` in `idb_shim.dart`
* Allow safe import of `idb_shim.dart` on web and io.

## 1.11.0

* Add support for `DateTime` and `Uint8List`,
* fix meta export to always save the same order for stores and indecies

## 1.10.3+1

* Support keyPath array for index

## 1.10.2

* Pedantic 1.9

## 1.10.1

* Add support for `idb_sqflite`, an implementation for flutter mobile on top of sqflite
* Add support for service worker self.indexedDB

## 1.9.0

* Deprecates old names (sorry) and websql
* Fix update/delete in index cursor for sembast
* Sdk 2.4 min

## 1.8.0+3

* Sdk 2.5 support

## 1.7.6+1

* add support for `ObjectStore.openKeyCursor`

## 1.7.5

* Supports dart 2.3

## 1.7.4

* Supports multiEntry for sembast implementation
* Fix cursor update with keyPath for sembast

## 1.7.3

* Fix dot support in keyPath to match native behavior

## 1.7.2

* Dart 2.2 support, Dart 2.1 compatible

## 1.7.0

* remove websql support
* support keyPath as array

## 1.6.0

* dart2 only, no websql yet

## 1.5.0

* Dart2 compatible (except websql shim)
* Depends on sembast 1.7.0

## 1.4.2

* Add `implicit-cast: false` support

## 1.4.0

* Depends on sembast 1.4.0

## 1.3.6

* Add IdbFactory.cmp

## 1.3.5

* Simulate multistore transaction on Safari

## 1.3.3

* Add support for import/export (sembast export format)
* Fix timing to mimic IE limitation
* Add workaround for transaction bug in sdk 1.13

## 1.3.2

* Fix implementation for IE/Edge where the transaction life-cycle is shorter

## 1.3.1

* Add support for ObjectStore.deleteIndex

## 1.2.1

* Fix openCursor for Index that included null key before (sembast)
* Travis test integration

## 1.0.0

* Initial revision 