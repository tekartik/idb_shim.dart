# idb shim

Pure dart indexed db like API on top of native, websql or memory implementation. Its goal is to support browser such as
Safari and any browser on iOS (that do not support the indexed_db api) with very few changes.

* Project [home page](http://alextekartik.github.io/idb_shim.dart/)
* Project [source code](https://github.com/alextekartik/idb_shim.dart)
* [Samples](https://alextekartik.github.io/idb_shim_samples.dart) (code and live demo)

[![Build Status](https://drone.io/github.com/alextekartik/idb_shim.dart/status.png)](https://drone.io/github.com/alextekartik/idb_shim.dart/latest)

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

All other existing code remains unchanged (well at least that it is the goal)

### Author
 * [Alexandre Roux Tekartik](https://github.com/alextekartik) ([+Alexandre Roux Tekartik](https://plus.google.com/+AlexandreRouxTekartik/about))
 
### Known limitations/issues

* For autoincrement, key cannot be set as a different type than int
* Native exception type have no match in the dart so a custom string or error is sometimes created
* Nextunique and prevunique not support (for now)
* No support for Cursor.source
* Next with key (on Cursor) not supported
* No support for blocked. It is always possible to upgrade the database, however other tabs will get blocked in their future calls
* Blocked and onVersionChange event support, this is actually tricky for websql, actually the new db won't be blocked but the old one will!
  so the proper common implementation is to register for onVersionChange event and when receiving simply reload the page. Sample code to come
* Type of data
 * Only stuff that can be JSON serialized/deserialized
 * DateTime is not supported, it should be converted to string using toIso8601String
 * Cyclic dependecy are not supported (per JSON serialization)
 * Large float are not converted to int (native indexeddb implementation does this)
* Index.get: only by key is supported (no range yet)
* WebSql implementation issue SqlResultSet.rows.first is not working in dart2js (bug?)
* When adding an index, existing data is not indexed yet

