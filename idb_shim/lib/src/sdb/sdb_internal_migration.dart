import '../../sdb.dart';

/// Initial format with Timestamp and Blob encoding
// ignore: unused_element
var _version1 = 1;

/// Change Timestamp encoding - 2026-04-23
// ignore: unused_element
var _version2 = 2;

/// Migration extension
extension SdbClientMigrationExtension on SdbClient {
  /// Null means all stores
  Future<void> compatMigrate1To2({List<String>? stores}) async {
    stores ??= List.of(storeNames);
    for (final storeName in stores) {
      var store = SdbStoreRef<Object, Object>(storeName);
      await store.handleRecords(
        this,
        handler: (row) {
          //row.
        },
      );
    }
  }
}
