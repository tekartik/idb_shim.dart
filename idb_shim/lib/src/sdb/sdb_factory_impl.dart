import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:idb_shim/src/utils/env_utils.dart';

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
    SdbOpenDatabaseOptions? options,

    /// Compat, version
    @Deprecated('Use options instead') int? version,

    /// Compat, onVersionChange
    @Deprecated('Use options instead')
    SdbOnVersionChangeCallback? onVersionChange,

    /// Compat, schema
    @Deprecated('Use options instead') SdbDatabaseSchema? schema,
  }) async {
    options ??= SdbOpenDatabaseOptions();
    options = options.copyWith(
      version: version,
      schema: schema,
      onVersionChange: onVersionChange,
    );
    return await openDatabaseImpl(name, options);
  }

  /// Open the database.
  Future<SdbDatabase> openDatabaseImpl(
    String name,
    SdbOpenDatabaseOptions options,
  ) async {
    final db = SdbDatabaseImpl(this, name, openOptions: options);

    var onUpgradeNeededCalled = false;
    var schema = options.schema;
    var onVersionChange = options.onVersionChange;
    // version could be null even when the schema is specified
    // this could work for an openDatabase that already exists.
    var version = options.version;
    /*
    var db = await _impl.openDatabaseImpl(
      name,
      version: version,
      onVersionChange: (event) {
        onVersionChangeCalled = true;
        applySchema(event, schema);
      },
      schema: schema,
    );
    if (isDebug && !onVersionChangeCalled) {
      try {
        await checkSchema(db, schema);
      } catch (e) {
        await db.close();
        rethrow;
      }
    }
    return db;

     */

    var onUpgradeNeeded = (onVersionChange != null || schema != null)
        ? (idb.VersionChangeEvent event) {
            onUpgradeNeededCalled = true;
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
            if (schema != null) {
              SchemaSdbDatabasePrvExtension.applySchema(
                dbVersionChangeEvent,
                schema,
              );
            }
            if (onVersionChange != null) {
              return onVersionChange(dbVersionChangeEvent);
            }
          }
        : null;
    var idbDatabase = await idbFactory.open(
      name,
      version: version,
      onUpgradeNeeded: onUpgradeNeeded,
    );
    db.idbDatabase = idbDatabase;
    if (isDebug && schema != null && !onUpgradeNeededCalled) {
      try {
        await db.checkSchema(schema);
      } catch (e) {
        await db.close();
        rethrow;
      }
    }
    return db;
  }
}
