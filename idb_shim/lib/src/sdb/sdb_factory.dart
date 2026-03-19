import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/sdb/sdb_factory_impl.dart';

import 'sdb.dart';

/// Abstract SDB Database factory.
///
/// Use [sdbFactoryWeb] on the web, [sdbFactoryIo] for a default io implementation
/// that uses sembast but prefer `sdbFactorySqflite` from package `idb_sqflite`.
/// for a more robust iOS/Android/Desktop implementation.
/// For testing, use [sdbFactoryMemory] or [newSdbFactoryMemory] to create a
/// factory in memory
abstract class SdbFactory implements SdbFactoryInterface {}

/// Mixin helper for default implementation.
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

  /// provide onVersionChange to handle schema changes or initialization
  /// manually, this is called after automatic schema change
  SdbOnVersionChangeCallback? get onVersionChange;

  /// Options for opening a Sdb database.
  factory SdbOpenDatabaseOptions({
    int? version,
    SdbDatabaseSchema? schema,
    SdbOnVersionChangeCallback? onVersionChange,
  }) => _SdbOpenDatabaseOptions(
    version: version,
    schema: schema,
    onVersionChange: onVersionChange,
  );

  /// Copy with new values.
  SdbOpenDatabaseOptions copyWith({
    int? version,
    SdbDatabaseSchema? schema,
    SdbOnVersionChangeCallback? onVersionChange,
  });
}

/// Options for opening a Sdb database.
class _SdbOpenDatabaseOptions implements SdbOpenDatabaseOptions {
  @override
  SdbOpenDatabaseOptions copyWith({
    int? version,
    SdbDatabaseSchema? schema,
    SdbOnVersionChangeCallback? onVersionChange,
  }) {
    return _SdbOpenDatabaseOptions(
      version: version ?? this.version,
      schema: schema ?? this.schema,
      onVersionChange: onVersionChange ?? this.onVersionChange,
    );
  }

  /// The version of the database.
  @override
  final int? version;

  /// The schema of the database.
  @override
  final SdbDatabaseSchema? schema;

  /// The version change callback.
  @override
  final SdbOnVersionChangeCallback? onVersionChange;

  /// Options for opening a Sdb database.
  _SdbOpenDatabaseOptions({this.version, this.schema, this.onVersionChange});
}

/// Sdb Factory interface.
abstract class SdbFactoryInterface {
  /// Open a database.
  ///
  /// [name] is the path of the database.
  /// [version] is the version of the database. If the existing database has a
  /// lower version, [onVersionChange] will be called.
  /// [onVersionChange] is called when the database is created or upgraded.
  /// [schema] provides an automatic way to handle version changes.
  ///
  /// Either [onVersionChange] or [schema] should be provided for schema
  /// definition and migration.
  ///
  /// Example:
  /// ```dart
  /// class SchoolDb {
  ///   final schoolStore = SdbStoreRef<String, SdbModel>('school');
  ///   final studentStore = SdbStoreRef<int, SdbModel>('student');
  ///
  ///   /// Index on studentStore for field 'schoolId'
  ///   late final studentSchoolIndex = studentStore.index<String>(
  ///     'school',
  ///   ); // On field 'schoolId'
  ///   late final schoolDbSchema = SdbDatabaseSchema(
  ///     stores: [
  ///       schoolStore.schema(),
  ///       studentStore.schema(
  ///         autoIncrement: true,
  ///         indexes: [studentSchoolIndex.schema(keyPath: 'schoolId')],
  ///       ),
  ///     ],
  ///   );
  ///
  ///   Future<SdbDatabase> open(SdbFactory factory, String dbName) async {
  ///     return factory.openDatabase(
  ///       dbName,
  ///       options: SdbOpenDatabaseOptions(
  ///         version: 1,
  ///         schema: schoolDbSchema,
  ///       ),
  ///     );
  ///   }
  /// }
  /// ```
  Future<SdbDatabase> openDatabase(
    String name, {

    /// Options for opening a Sdb database (prefer options over version and schema).
    SdbOpenDatabaseOptions? options,

    /// The version of the database, prefer options
    int? version,

    /// compat: provide onVersionChange to handle schema changes or initialization
    /// Prefer options
    SdbOnVersionChangeCallback? onVersionChange,

    /// compat: provide a schema to have it applied automatically.
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

  /// Open a database, deleting it on downgrade.
  ///
  /// This is a convenient helper for development to handle hot-restart.
  /// If a downgrade is detected, the database is deleted and re-opened.
  Future<SdbDatabase> openDatabaseOnDowngradeDelete(
    String name, {

    /// Options for opening a Sdb database (prefer options over version and schema).
    SdbOpenDatabaseOptions? options,
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
  }) async {
    Future<SdbDatabase> doOpen() {
      return openDatabase(
        name,
        options: options,
        version: version,
        onVersionChange: onVersionChange,
      );
    }

    version ??= options?.version;
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
