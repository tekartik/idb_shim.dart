import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/sdb/sdb_factory_impl.dart';

import 'sdb.dart';

/// Sdb Factory
abstract class SdbFactory implements SdbFactoryInterface {}

/// Mixin helper
mixin SdbFactoryDefaultMixin implements SdbFactory {
  @override
  Future<SdbDatabase> openDatabase(
    String name, {
    SdbOpenDatabaseOptions? options,
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
    SdbDatabaseSchema? schema,
  }) {
    throw UnsupportedError('openDatabase');
  }

  @override
  Future<void> deleteDatabase(String name) async {
    throw UnsupportedError('deleteDatabase');
  }
}

/// Options for opening a Sdb database.
abstract class SdbOpenDatabaseOptions {
  /// The version of the database.
  int? get version;

  /// The schema of the database.
  SdbDatabaseSchema? get schema;

  /// Options for opening a Sdb database.
  factory SdbOpenDatabaseOptions({int? version, SdbDatabaseSchema? schema}) =>
      _SdbOpenDatabaseOptions(version: version, schema: schema);

  /// Copy with.
  SdbOpenDatabaseOptions copyWith({int? version, SdbDatabaseSchema? schema});
}

/// Options for opening a Sdb database.
class _SdbOpenDatabaseOptions implements SdbOpenDatabaseOptions {
  @override
  SdbOpenDatabaseOptions copyWith({int? version, SdbDatabaseSchema? schema}) {
    return _SdbOpenDatabaseOptions(
      version: version ?? this.version,
      schema: schema ?? this.schema,
    );
  }

  /// The version of the database.
  @override
  final int? version;

  /// The schema of the database.
  @override
  final SdbDatabaseSchema? schema;

  /// Options for opening a Sdb database.
  _SdbOpenDatabaseOptions({this.version, this.schema});
}

/// Sdb Factory interface.
abstract class SdbFactoryInterface {
  /// Open a database.
  Future<SdbDatabase> openDatabase(
    String name, {
    SdbOpenDatabaseOptions? options,

    /// The version of the database prefer options
    int? version,

    /// Either provide onVersionChange to handle schema changes
    /// manually...
    SdbOnVersionChangeCallback? onVersionChange,

    /// ...or provide a schema to have it applied automatically.
    /// Prefer options
    SdbDatabaseSchema? schema,
  });

  /// Delete a database.
  Future<void> deleteDatabase(String name);
}

/// Sdb Factory extension.
extension SdbFactoryExtension on SdbFactory {
  SdbFactoryIdb get _factoryIdb => this as SdbFactoryIdb;

  /// Get the underlying idbFactory.
  IdbFactory get idbFactory => _factoryIdb.idbFactory;

  /// Open a database.
  Future<SdbDatabase> openDatabaseOnDowngradeDelete(
    String name, {
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
  }) async {
    Future<SdbDatabase> doOpen() {
      return openDatabase(
        name,
        version: version,
        onVersionChange: onVersionChange,
      );
    }

    if (version == null) {
      return doOpen();
    }
    try {
      return await doOpen();
    } catch (e) {
      // ignore: avoid_print
      print('openOnDowngradeDelete: error ${e.runtimeType} $e');

      /// There is no good way to detect a downgrade, try to open without version to check the version
      var db = await openDatabase(name);
      var isDowngrade = version < db.version;
      await db.close();

      if (isDowngrade) {
        await deleteDatabase(name);
      } else {
        rethrow;
      }
      return await doOpen();
    }
  }
}
