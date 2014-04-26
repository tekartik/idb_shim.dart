IndexedDB shim
==============

Pure dart indexed db like API on top of native, websql or memory implementation. Can replace
existing code that use the regulrar indexeddb_api with very few changes

Assume you have the existing

```
import 'dart:indexed_db';
window.indexedDB.open(dbName, version: xxx, onUpgradeNeeded: yyy);
```

This can be replaced using

```
import 'package:idb_shim/idb_browser.dart'
IdbFactory idbFactory = getIdbFactory();
idbFactory.open(dbName, version: xxx, onUpgradeNeeded: yyy);
```

All other existing code remains unchanged
