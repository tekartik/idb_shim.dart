import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sdb/sdb_factory_impl.dart';
import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:idb_shim/src/utils/env_utils.dart';

import 'sdb_database_impl.dart';

/// Store schema definition
class SdbStoreSchemaDef {
  /// Store name
  final String name;

  /// Key path
  final SdbKeyPath? keyPath;

  /// Auto increment
  final bool autoIncrement;

  /// Indexes - sorted by name
  final List<SdbIndexSchemaDef> indexes;

  /// Store schema definition
  SdbStoreSchemaDef({
    required this.name,
    this.keyPath,
    this.autoIncrement = false,
    List<SdbIndexSchemaDef> indexes = const [],
  }) : indexes = List.of(indexes)
         ..sort((index1, index2) => index1.name.compareTo(index2.name));

  @override
  int get hashCode => name.hashCode;
  @override
  bool operator ==(Object other) {
    if (other is! SdbStoreSchemaDef) {
      return false;
    }
    if (name != other.name ||
        keyPath != other.keyPath ||
        autoIncrement != other.autoIncrement) {
      return false;
    }
    if (indexes.length != other.indexes.length) {
      return false;
    }
    for (var i = 0; i < indexes.length; i++) {
      if (indexes[i] != other.indexes[i]) {
        return false;
      }
    }
    return true;
  }

  /// Debug map
  Map<String, Object?> toDebugMap({bool noName = false}) {
    final map = <String, Object?>{
      if (!noName) 'name': name,
      if (autoIncrement) 'autoIncrement': autoIncrement,
      if (indexes.isNotEmpty)
        'indexes': {
          for (var index in indexes) index.name: index.toDebugMap(noName: true),
        },
    };
    _debugMapAddKeyPath(map, keyPath);

    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }
}

/// Index schema definition
class SdbIndexSchemaDef {
  /// Index name
  final String name;

  /// Key path
  final SdbKeyPath keyPath;

  /// Unique
  final bool unique;

  /// Index schema definition
  SdbIndexSchemaDef({
    required this.name,
    required Object keyPath,
    required this.unique,
  }) : keyPath = sdbKeyPathFromAny(keyPath);

  /// Debug map
  Map<String, Object?> toDebugMap({bool noName = false}) {
    final map = <String, Object?>{
      if (!noName) 'name': name,
      if (unique) 'unique': unique,
    };
    _debugMapAddKeyPath(map, keyPath);
    return map;
  }

  @override
  int get hashCode => name.hashCode;
  @override
  bool operator ==(Object other) {
    if (other is! SdbIndexSchemaDef) {
      return false;
    }
    return name == other.name &&
        keyPath == other.keyPath &&
        unique == other.unique;
  }
}

/// Database schema definition
class SdbDatabaseSchemaDef {
  /// Stores
  final List<SdbStoreSchemaDef> stores;

  /// Database schema definition
  SdbDatabaseSchemaDef({List<SdbStoreSchemaDef> stores = const []})
    : stores = List.of(stores)
        ..sort((store1, store2) => store1.name.compareTo(store2.name));

  @override
  int get hashCode => stores.firstOrNull?.hashCode ?? 0;
  @override
  bool operator ==(Object other) {
    if (other is! SdbDatabaseSchemaDef) {
      return false;
    }
    if (stores.length != other.stores.length) {
      return false;
    }
    for (var i = 0; i < stores.length; i++) {
      if (stores[i] != other.stores[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => '${toDebugMap()}';

  /// Debug map
  Map<String, Object?> toDebugMap() {
    final map = <String, Object?>{
      'stores': {
        for (var store in stores) store.name: store.toDebugMap(noName: true),
      },
    };
    return map;
  }
}

/// Database schema extension
extension SdbDatabaseSchemaExtensionPrv on SdbDatabaseSchema {
  /// Find store schema by name
  SdbStoreSchema findStoreSchema(String storeName) {
    for (var storeSchema in stores) {
      if (storeSchema.name == storeName) {
        return storeSchema;
      }
    }
    throw StateError('Store $storeName not found in schema');
  }
}

/// Store schema
class SdbStoreSchema {
  /// Store reference
  final SdbStoreRef ref;

  /// Key path
  final SdbKeyPath? keyPath;

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

  @override
  String toString() => def.toString();
}

/// Store schema extension
extension SdbStoreSchemaExtensionPrv on SdbStoreSchema {
  /// Find store schema by name
  SdbIndexSchema findIndex(String indexName) {
    for (var indexSchema in indexes) {
      if (indexSchema.name == indexName) {
        return indexSchema;
      }
    }
    throw StateError('Index $indexName not found in store $this');
  }

  /// Store schema definition
  SdbStoreSchemaDef get def {
    return SdbStoreSchemaDef(
      name: name,
      keyPath: keyPath,
      autoIncrement: autoIncrement,
      indexes: indexes.map((index) => index.def).toList(),
    );
  }
}

/// Store schema extension
extension SdbStoreSchemaExtension on SdbStoreSchema {
  /// Helper
  Iterable<String> get indexNames =>
      indexes.map((indexSchema) => indexSchema.name);

  /// Store name
  String get name => ref.name;
}

/// Key path abstraction
abstract class SdbKeyPath {
  /// Key paths (1 or more, never empty)
  List<String> get keyPaths; // Never empty
  /// Create single key path
  factory SdbKeyPath.single(String keyPath) => _SdbKeySinglePath(keyPath);

  /// Create multi key path
  factory SdbKeyPath.multi(List<String> keyPaths) => _SdbKeyMultiPath(keyPaths);
}

abstract class _SdbKeyPathBase implements SdbKeyPath {
  @override
  String toString() {
    if (isSingle) {
      return keyPaths.first;
    } else {
      return keyPaths.toString();
    }
  }

  @override
  int get hashCode => keyPaths.first.hashCode;
  @override
  bool operator ==(Object other) {
    if (other is! SdbKeyPath) {
      return false;
    }
    return valueListEquals(keyPaths, other.keyPaths);
  }
}

/// Key path extension
extension SdbKeyPathExtension on SdbKeyPath {
  /// True if single key path
  bool get isSingle => keyPaths.length == 1;

  /// True if multi key path
  bool get isMulti => keyPaths.length > 1;
}

class _SdbKeySinglePath extends _SdbKeyPathBase {
  final String keyPath;

  _SdbKeySinglePath(this.keyPath);

  @override
  List<String> get keyPaths => [keyPath];
}

class _SdbKeyMultiPath extends _SdbKeyPathBase {
  @override
  final List<String> keyPaths;
  _SdbKeyMultiPath(this.keyPaths) {
    assert(keyPaths.length >= 2);
  }
}

/// Store schema extension on store ref
extension SdbStoreRefSchemaExtension on SdbStoreRef {
  /// Create store schema
  SdbStoreSchema schema({
    SdbKeyPath? keyPath,
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
  /// Create store schema, keyPath is String, a `List<String>` or SdbKeyPath
  SdbIndexSchema schema({required Object keyPath}) {
    return SdbIndexSchema(this, sdbKeyPathFromAny(keyPath));
  }
}

/// Index schema
class SdbIndexSchema {
  /// Index reference
  final SdbIndexRef ref;

  /// Key paths
  final SdbKeyPath keyPath;

  /// Unique
  final bool unique;

  /// Index schema
  SdbIndexSchema(this.ref, this.keyPath, {this.unique = false});

  /// Index schema definition
  SdbIndexSchemaDef get def {
    return SdbIndexSchemaDef(name: ref.name, keyPath: keyPath, unique: unique);
  }

  @override
  String toString() => def.toString();
}

/// Index schema extension
extension SdbIndexSchemaExtension on SdbIndexSchema {
  /// Index name
  String get name => ref.name;
}

/// Database schema
///
/// Rules applied.
/// - Stores not in schema are deleted
/// - Store schema changes (key path, auto increment) are not supported, an error is thrown
/// - Index schema changes (key path) are not supported, an error is thrown
/// - Indexes not in schema are deleted
class SdbDatabaseSchema {
  /// Stores schemas
  final List<SdbStoreSchema> stores;

  /// Database schema
  SdbDatabaseSchema({required this.stores});
}

/// Database schema extension
extension SdbDatabaseSchemaExtension on SdbDatabaseSchema {
  /// store names
  Iterable<String> get storeNames =>
      stores.map((storeSchema) => storeSchema.ref.name);

  /// store refs
  List<SdbStoreRef> get storeRefs => stores.map((s) => s.ref).toList();

  /// Database schema definition
  SdbDatabaseSchemaDef get def {
    return SdbDatabaseSchemaDef(
      stores: stores.map((storeSchema) => storeSchema.def).toList(),
    );
  }
}

/// Factory schema extension
extension SdbFactorySchemaExtension on SdbFactory {}

/// Factory schema extension
extension SdbFactorySchemaExtensionPrv on SdbFactory {
  SdbFactoryImpl get _impl => this as SdbFactoryIdb;
  static Future<void> _onCheckSchema(
    SdbDatabase db,
    SdbDatabaseSchema schema,
  ) async {
    var storeNames = db.storeNames.toSet();
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
            var keyPath = indexSchema.keyPath;
            var index = store.index(indexRef);
            if (keyPath != index.keyPath) {
              throw StateError(
                'Index key path mismatch for index ${indexRef.name} in store ${store.name}:'
                ' expected ${indexSchema.keyPath} was ${index.keyPath}'
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

      /// Can only be a string

      var keyPath = storeSchema.keyPath?.keyPaths.first;

      if (!storeNames.contains(storeRef.name)) {
        store = db.createStore(
          storeRef,
          keyPath: keyPath,
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
      var existingIndexNames = store.indexNames.toSet();

      /// Delete index not in schema
      for (var indexName in existingIndexNames) {
        if (!schemaIndexNames.contains(indexName)) {
          store.deleteIndex(indexName);
        }
      }
      for (var indexSchema in schemaIndexes) {
        var indexRef = indexSchema.ref;
        var keyPath = indexSchema.keyPath;
        var indexName = indexSchema.name;
        var unique = indexSchema.unique;
        if (!existingIndexNames.contains(indexName)) {
          store.createIndex(indexRef, keyPath);
        } else {
          var index = store.index(indexRef);
          var existingKeyPath = index.keyPath;
          if (existingKeyPath != keyPath) {
            throw StateError(
              'Index key path change not supported for index $indexName in store ${storeRef.name}'
              '\nCreate a new index with the new key path and delete the old one (chaning the name should work).',
            );
          }
          var existingUnique = index.unique;
          if (existingUnique != unique) {
            throw StateError(
              'Index unique change not supported for index $indexName in store ${storeRef.name}'
              '\nCreate a new index with the new key path and delete the old one (chaning the name should work).',
            );
          }
        }
      }
    }
  }

  /// Get the database schema.
  Future<SdbDatabase> openWithSchema(
    String name,
    SdbDatabaseSchema schema, {
    int? version,
  }) async {
    var onVersionChangeCalled = false;
    var db = await _impl.openDatabaseImpl(
      name,
      version: version,
      onVersionChange: (event) {
        onVersionChangeCalled = true;
        _onApplySchema(event, schema);
      },
      schema: schema,
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

/// Database schema extension on database
extension SchemaSdbDatabaseExtension on SdbDatabase {
  SdbDatabaseImpl get _impl => this as SdbDatabaseImpl;

  /// Read the database schema definition
  Future<SdbDatabaseSchemaDef> readSchemaDef() {
    var schema = _impl.schema;
    if (schema == null) {
      throw StateError('Database was not opened with a schema');
    }

    var stores = storeNames;
    return inStoresTransaction(
      stores
          .map((storeName) => schema.findStoreSchema(storeName))
          .map((schema) => schema.ref)
          .toList(),
      SdbTransactionMode.readOnly,
      (txn) {
        return txnReadSchemaDef(txn);
      },
    );
  }
}

/// Private Database schema extension on database
extension SchemaSdbDatabasePrvExtension on SdbDatabase {
  /// Read the database schema definition
  SdbDatabaseSchemaDef txnReadSchemaDef(SdbTransaction txn) {
    var schema = _impl.schema!;
    var storeNames = txn.storeNames;

    var storesDefs = storeNames.map((storeName) {
      final storeSchema = schema.findStoreSchema(storeName);
      var storeRef = storeSchema.ref;
      final store = txn.store(storeRef);
      final keyPath = store.keyPath;
      final autoIncrement = store.autoIncrement;

      var indexDefs = store.indexNames.map((indexName) {
        var indexSchema = storeSchema.findIndex(indexName);
        var keyPath = indexSchema.keyPath;
        var unique = indexSchema.unique;
        return SdbIndexSchemaDef(
          name: indexName,
          keyPath: keyPath,
          unique: unique,
        );
      }).toList();

      return SdbStoreSchemaDef(
        name: storeName,
        keyPath: keyPath,
        autoIncrement: autoIncrement,
        indexes: indexDefs,
      );
    });
    return SdbDatabaseSchemaDef(stores: storesDefs.toList());
  }
}

void _debugMapAddKeyPath(Map map, SdbKeyPath? keyPath) {
  if (keyPath != null) {
    if (keyPath.isSingle) {
      map['keyPath'] = keyPath.keyPaths.first;
    } else {
      map['keyPath'] = keyPath.keyPaths;
    }
  }
}
