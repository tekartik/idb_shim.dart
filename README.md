# idb shim

Pure dart indexed db like API on top of native, websql or memory implementation. Its goal is to support browsers that do
not support the indexed_db api with very few changes.

It also  allows to test your database schema and access in vm unit tests.

* Project [home page](http://alextekartik.github.io/idb_shim.dart/)
* Project [source code](https://github.com/alextekartik/idb_shim.dart)
* [Samples](https://alextekartik.github.io/idb_shim_samples.dart) (code and live demo)

[![Build Status](https://travis-ci.org/alextekartik/idb_shim.dart.svg?branch=master)](https://travis-ci.org/alextekartik/idb_shim.dart)

### Usage

Assume you have the existing:

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

All other existing code remains unchanged. Simple example below:

```dart
// define the store name
const String storeName = "records";

// open the database
Database db = await idbFactory.open("my_records.db", version: 1,
    onUpgradeNeeded: (VersionChangeEvent event) {
  Database db = event.database;
  // create the store
  db.createObjectStore(storeName, autoIncrement: true);
});

// put some data
var txn = db.transaction(storeName, "readwrite");
var store = txn.objectStore(storeName);
var key = await store.put({"some": "data"});
await txn.completed;

// read some data
txn = db.transaction(storeName, "readonly");
store = txn.objectStore(storeName);
Map value = await store.getObject(key);
await txn.completed;
```

### Author
 * [Alexandre Roux Tekartik](https://github.com/alextekartik) ([+Alexandre Roux Tekartik](https://plus.google.com/+AlexandreRouxTekartik/about))
 
### Known limitations/issues

#### Memory/Io/WebSql implementation

* For autoincrement, if key is set, it cannot be set as a different type than int
* Nextunique and prevunique not support (for now)
* No support for Cursor.source
* No generic support for blocked. It is always possible to upgrade the database, however other tabs will get blocked in their future calls
* Blocked and onVersionChange event support, this is actually tricky for websql, actually the new db won't be blocked but the old one will!
  so the proper common implementation is to register for onVersionChange event and when receiving simply reload the page. Sample code to come
* Index.get: only by key is supported (no range yet)
* WebSql implementation issue SqlResultSet.rows.first is not working in dart2js (bug?)

##### Type of data

* Only stuff that can be JSON serialized/deserialized
* DateTime is not supported, it should be converted to string using toIso8601String
* Cyclic dependecy are not supported (per JSON serialization)
* Large float are not converted to int (native indexeddb implementation does this)

##### Type of key

* String and num (double and int) are supported
* DateTime is not supported, convert them to String

#### Native exception

* Native exception type have no match in dart so a custom DatabaseError object is created to wrap the exception

### Ie limitation

IE 11, Edge 12 has the following limitations:

* no support for reading objectStore.autoIncrement properties
* ObjectStore.count() without argument throw a 'DataError' exception...better avoid count() on IE...
