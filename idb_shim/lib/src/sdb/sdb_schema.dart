import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:idb_shim/src/utils/env_utils.dart';

/// Store schema
class SdbStoreSchema {
  /// Store reference
  final SdbStoreRef ref;

  /// Key path
  final String? keyPath;

  /// Auto increment
  final bool autoIncrement;

  /// Indexes
  final List<SdbIndexSchema> indexes;

  /// Store schema
  SdbStoreSchema(
    this.ref, {
    this.keyPath,
    this.autoIncrement = false,
    this.indexes = const [],
  });
}

/// Store schema extension
extension SdbStoreSchemaExtension on SdbStoreSchema {
  /// Helper
  Iterable<String> get indexNames =>
      indexes.map((indexSchema) => indexSchema.ref.name);
}

/// Store schema extension on store ref
extension SdbStoreRefSchemaExtension on SdbStoreRef {
  /// Create store schema
  SdbStoreSchema schema({
    String? keyPath,
    bool? autoIncrement,
    List<SdbIndexSchema>? indexes,
  }) {
    return SdbStoreSchema(
      this,
      keyPath: keyPath,
      autoIncrement: autoIncrement ?? false,
      indexes: indexes ?? [],
    );
  }
}

/// Store schema extension on store ref
extension SdbIndexRefSchemaExtension on SdbIndex1Ref {
  /// Create store schema
  SdbIndexSchema schema({required String keyPath}) {
    return SdbIndexSchema(this, [keyPath]);
  }
}

/// Index schema
class SdbIndexSchema {
  /// Index reference
  final SdbIndexRef ref;

  /// Key paths
  final List<String> keyPaths;

  /// Index schema
  SdbIndexSchema(this.ref, this.keyPaths);
}

/// Database schema
class SdbDatabaseSchema {
  /// Version required
  final int version;

  /// Stores schemas
  final List<SdbStoreSchema> stores;

  /// Database schema
  SdbDatabaseSchema({required this.version, required this.stores});
}

/// Database schema extension
extension SdbDatabaseSchemaExtension on SdbDatabaseSchema {
  /// store names
  Iterable<String> get storeNames =>
      stores.map((storeSchema) => storeSchema.ref.name);

  /// store refs
  List<SdbStoreRef> get storeRefs => stores.map((s) => s.ref).toList();
}

/// Factory schema extension
extension SdbFactorySchemaExtension on SdbFactory {
  static Future<void> _onCheckSchema(
    SdbDatabase db,
    SdbDatabaseSchema schema,
  ) async {
    var storeNames = db.objectStoreNames.toSet();
    var storeSchemas = schema.stores;
    // To find the delete ones first
    var schemaStoreNames = schema.storeNames.toSet();

    if (!valueSetEquals(storeNames, schemaStoreNames)) {
      throw StateError(
        'Database schema does not match. Expected stores: $schemaStoreNames, found stores: $storeNames'
        ', update database version to force update',
      );
    }
    return await db.inStoresTransaction(
      schema.storeRefs,
      SdbTransactionMode.readOnly,
      (txn) async {
        /// Delete stores not in schema
        for (var storeSchema in storeSchemas) {
          var store = txn.store(storeSchema.ref);
          var storeKeyPath = store.keyPath; // Access to ensure store exists
          var storeSchemaKeyPath = storeSchema.keyPath;
          if (storeKeyPath != storeSchemaKeyPath) {
            throw StateError(
              'Key path mismatch for store ${storeSchema.ref.name}: expected $storeSchemaKeyPath'
              ', update database version to force update',
            );
          }
          if (store.autoIncrement != storeSchema.autoIncrement) {
            throw StateError(
              'Auto increment mismatch for store ${storeSchema.ref.name}: expected ${storeSchema.autoIncrement}'
              ', update database version to force update',
            );
          }

          var schemaIndexes = storeSchema.indexes;
          var schemaIndexNames = storeSchema.indexNames.toSet();
          var indexNames = store.indexNames.toSet();

          if (!valueSetEquals(indexNames, schemaIndexNames)) {
            throw StateError(
              'Store index schema does not match in store ${store.name}.'
              ' Expected indexes: $schemaIndexNames, found indexes: $indexNames'
              ', update database version to force update',
            );
          }

          /// Delete index not in schema

          for (var indexSchema in schemaIndexes) {
            var indexRef = indexSchema.ref;
            var keyPaths = indexSchema.keyPaths;
            var index = store.index(indexRef);
            if (!valueListEquals(keyPaths, index.keyPaths)) {
              throw StateError(
                'Index key path mismatch for index ${indexRef.name} in store ${store.name}:'
                ' expected ${indexSchema.keyPaths} was ${index.keyPaths}'
                ', update database version to force update',
              );
            }
          }
        }
      },
    );

    // Implement schema upgrade logic here using the provided schema
  }

  static void _onApplySchema(
    SdbVersionChangeEvent event,
    SdbDatabaseSchema schema,
  ) {
    var db = event.db;
    var storeNames = db.objectStoreNames.toSet();
    // To find the delete ones first
    var schemaStoreNames = schema.storeNames.toSet();

    /// Delete stores not in schema
    for (var storeName in storeNames) {
      if (!schemaStoreNames.contains(storeName)) {
        db.deleteStore(storeName);
      }
    }

    for (var storeSchema in schema.stores) {
      var storeRef = storeSchema.ref;
      SdbOpenStoreRef store;
      if (!storeNames.contains(storeRef.name)) {
        store = db.createStore(
          storeRef,
          keyPath: storeSchema.keyPath,
          autoIncrement: storeSchema.autoIncrement,
        );
      } else {
        store = db.objectStore(storeRef);
        var schemaKeyPath = storeSchema.keyPath;
        if (schemaKeyPath != storeSchema.keyPath) {
          throw StateError(
            'Key path change not supported for store ${storeRef.name}',
          );
        }
      }
      var schemaIndexes = storeSchema.indexes;
      var schemaIndexNames = storeSchema.indexNames.toSet();
      schemaIndexes.map((indexSchema) => indexSchema.ref.name).toSet();
      var indexNames = store.indexNames.toSet();

      /// Delete index not in schema
      for (var indexName in indexNames) {
        if (!schemaIndexNames.contains(indexName)) {
          store.deleteIndex(indexName);
        }
      }
      for (var indexSchema in schemaIndexes) {
        var indexRef = indexSchema.ref;
        var keyPaths = indexSchema.keyPaths;
        if (indexRef is SdbIndex1Ref) {
          store.createIndex(indexRef, keyPaths.first);
        } else {
          throw UnimplementedError(
            'Only SdbIndex1Ref is implemented in schema for now',
          );
        }
      }
    }
  }

  /// Get the database schema.
  Future<SdbDatabase> openWithSchema(
    String name,
    SdbDatabaseSchema schema,
  ) async {
    var onVersionChangeCalled = false;
    var db = await openDatabase(
      name,
      version: schema.version,
      onVersionChange: (event) {
        onVersionChangeCalled = true;
        _onApplySchema(event, schema);
      },
    );
    if (isDebug && !onVersionChangeCalled) {
      try {
        await _onCheckSchema(db, schema);
      } catch (e) {
        await db.close();
        rethrow;
      }
    }
    return db;
  }
}
