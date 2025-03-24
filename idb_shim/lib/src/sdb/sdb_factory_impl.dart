import 'package:idb_shim/idb_shim.dart' as idb;

import 'sdb.dart';
import 'sdb_database_impl.dart';
import 'sdb_open_impl.dart';
import 'sdb_version.dart';

/// Compat
typedef SdbFactoryImpl = SdbFactoryIdb;

/// Sdb Factory implementation.
class SdbFactoryIdb implements SdbFactory {
  /// IndexedDB factory.
  final idb.IdbFactory idbFactory;

  /// Sdb Factory implementation.
  SdbFactoryIdb(this.idbFactory);

  /// Delete the database.
  @override
  Future<void> deleteDatabase(String name) {
    return idbFactory.deleteDatabase(name);
  }

  /// Open the database.
  @override
  Future<SdbDatabase> openDatabase(
    String name, {
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
  }) async {
    final db = SdbDatabaseImpl(this, name);
    var onUpgradeNeeded =
        onVersionChange != null
            ? (idb.VersionChangeEvent event) async {
              // print('onUpgradeNeeded: $event');
              //var db = event.database;
              var idbDatabase = event.database;
              var idbTransaction = event.transaction;
              final dbOpen = SdbOpenDatabaseImpl(db, idbTransaction);
              db.idbDatabase = idbDatabase;
              var oldVersion = event.oldVersion;
              var newVersion = event.newVersion;
              final dbVersionChangeEvent = SdbVersionChangeEventImpl(
                dbOpen,
                oldVersion,
                newVersion,
              );

              await onVersionChange(dbVersionChangeEvent);
            }
            : null;
    var idbDatabase = await idbFactory.open(
      name,
      version: version,
      onUpgradeNeeded: onUpgradeNeeded,
    );
    db.idbDatabase = idbDatabase;
    return db;
  }
}
