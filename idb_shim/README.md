# idb shim

Pure dart indexed db like API on top of native, sembast implementation. Its goal is to support browsers that do
not support the indexed_db api with very few changes as well as setting the base for a flutter implementation.

It also  allows to test your database schema and access in vm unit tests.

* Project [home page](http://tekartik.github.io/idb_shim.dart/)
* Project [source code](https://github.com/tekartik/idb_shim.dart)
* [Samples](https://tekartik.github.io/idb_shim_samples.dart) (code and live demo)

[![Build Status](https://travis-ci.org/tekartik/idb_shim.dart.svg?branch=master)](https://travis-ci.org/tekartik/idb_shim.dart)

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

### Example

Simple notepad available here.

### Flutter support

While idb_shim over sembast is a solution on Flutter, there is an implementation [idb_sqflite](https://pub.dev/packages/idb_sqflite) based on sqflite for mobile (iOS and Android)

### Author
 * [Alexandre Roux Tekartik](https://github.com/alextekartik) ([+Alexandre Roux Tekartik](https://plus.google.com/+AlexandreRouxTekartik/about))
 
### Testing

#### Testing with dartdevc

    pub serve test --web-compiler=dartdevc --port=8079
    pub run test -p chrome --pub-serve=8079

### Known limitations/issues

#### Memory/Io implementation

* For autoincrement, if key is set, it cannot be set as a different type than int
* Nextunique and prevunique not supported (for now)
* No support for Cursor.source
* No generic support for blocked. It is always possible to upgrade the database, however other tabs will get blocked in their future calls
* Index.get: only by key is supported (no range yet)

##### Type of data

* Only stuff that can be JSON serialized/deserialized
* DateTime is not supported, it should be converted to string using toIso8601String or int as milliseconds since epoch
* Cyclic dependecy are not supported (per JSON serialization)
* Large float are not converted to int (native indexeddb implementation does this)

##### Type of key

* String and num (int or double) are supported for keys

#### Native exception

* Native exception type have no match in dart so a custom DatabaseError object is created to wrap the exception

### Ie limitation

IE 11, Edge 12 has the following limitations:

* no support for reading objectStore.autoIncrement properties
* ObjectStore.count() without argument throw a 'DataError' exception...better avoid count() on IE...
* it seems ie close the transaction 'sooner' then chrome/firefox, i.e. calling an sync function that wrap an idb calls
  makes the transaction terminate
* IDBIndex.multiEntry not supported on ie

### Safari limitation

Safari has the following limitations (as of v 9.0)

* no support for transactions on multiple stores
* very short transaction life cycle (no await on sdk 1.12)

