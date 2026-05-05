import 'package:collection/collection.dart';
import 'package:idb_shim/src/sdb/sdb_client.dart';
import 'package:idb_shim/src/sdb/sdb_codec.dart';
import 'package:idb_shim/src/sdb/sdb_cursor.dart';
import 'package:idb_shim/src/sdb/sdb_database_impl.dart';
import 'package:meta/meta.dart';

import 'sdb.dart';

/// version1: Initial format with Timestamp and Blob encoding
// ignore: unused_element
var _version1 = 1;

/// version2: Change Timestamp encoding - 2026-04-23
// ignore: unused_element
var _version2 = 2;

/// Migrate raw value new format
Object rawValueCompatMigrate1To2(SdbCodec codec, Object value) {
  var sdbValue = codec.decode<Object>(value);
  var idbValue = codec.encode(sdbValue);
  return idbValue;
}

/// If 2 values are equals, entering nested list/map if any.
bool migrateValuesAreEqual(dynamic v1, dynamic v2) {
  try {
    return const DeepCollectionEquality().equals(v1, v2);
  } catch (_) {
    return v1 == v2;
  }
}

/// Migration extension
@experimental
extension SdbClientMigrationExtension on SdbClient {
  /// Null means all stores
  /// Need to convert SdbTimestamp format if you created before v2
  /// idb_shim
  Future<void> compatMigrate1To2({List<String>? stores}) async {
    stores ??= List.of(storeNames);
    for (final storeName in stores) {
      var store = SdbStoreRef<Object, Object>(storeName);
      await store.iterate(
        this,
        mode: SdbTransactionMode.readWrite,
        onRow: (row) {
          var initial = row.rawValue;
          var migrated = rawValueCompatMigrate1To2(
            interface.db.impl.codec,
            row.rawValue,
          );
          if (!migrateValuesAreEqual(migrated, initial)) {
            row.update(migrated);
          }
          return true;
        },
      );
    }
  }
}
