import 'package:idb_shim/idb_shim.dart' as idb;

import 'sdb.dart';
import 'sdb_database_impl.dart';
import 'sdb_open_impl.dart';
import 'sdb_schema.dart';
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
    SdbDatabaseSchema? schema,
  }) async {
    if (schema != null) {
      if (onVersionChange != null) {
        throw StateError(
          'Cannot provide both schema and onVersionChange callback',
        );
      }
      return await openWithSchema(name, schema, version: version);
    }
    return await openDatabaseImpl(
      name,
      version: version,
      onVersionChange: onVersionChange,
    );
  }

  /// Open the database.
  Future<SdbDatabase> openDatabaseImpl(
    String name, {
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
    SdbDatabaseSchema? schema,
  }) async {
    final db = SdbDatabaseImpl(this, name, schema: schema);
    var onUpgradeNeeded = onVersionChange != null
        ? (idb.VersionChangeEvent event) async {
            // print('onUpgradeNeeded: $event');
            //var db = event.database;
            var idbDatabase = event.database;
            var idbTransaction = event.transaction;

            final sdbOpenDatabase = SdbOpenDatabaseImpl(db, idbTransaction);
            final sdbOpenTransaction = SdbOpenTransactionImpl(
              sdbOpenDatabase,
              idbTransaction,
            );
            db.idbDatabase = idbDatabase;
            var oldVersion = event.oldVersion;
            var newVersion = event.newVersion;
            final dbVersionChangeEvent = SdbVersionChangeEventImpl(
              sdbOpenDatabase,
              sdbOpenTransaction,
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
