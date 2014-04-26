# idb shim

Pure dart indexed db like API on top of native, websql or memory implementation. Its goal is to support browser such as
Safari and any browser on iOS (that do not support the indexed_db api) with very few changes.

* Project [home page](http://alextekartik.github.io/idb_shim.dart/)
* Project [source code](https://github.com/alextekartik/idb_shim.dart)
* [Samples](https://alextekartik.github.io/idb_shim_samples.dart) (code and live demo)

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
 
