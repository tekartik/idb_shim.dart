## 2.0.0-nullsafety.5

* `nnbd` supports, breaking change.
* No longer supports `null` for record value.
* Remove deprecated methods.

## 1.12.2

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