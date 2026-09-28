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
abstract class SdbFactory implements SdbFactoryInterface {
  /// Debugging purpose
  String get name;

  /// Mainly use for debugging purpose
  Future<String> getDatabaseFullPath(String name);
}

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
    throw UnsupportedError('$runtimeType.openDatabase');
  }

  @override
  Future<void> deleteDatabase(String name) async {
    throw UnsupportedError('$runtimeType.deleteDatabase');
  }

  @override
  String toString() => 'SdbFactory($name)';
}

/// Options for opening a Sdb database.
abstract class SdbOpenDatabaseOptions {
  /// Options for opening a Sdb database.
  factory SdbOpenDatabaseOptions({
    int? version,
    SdbDatabaseSchema? schema,
    SdbOnVersionChangeCallback? onVersionChange,
    SdbCodec? codec,
    bool? closeOnVersionChange,
    SdbOnVersionChangeRequestCallback? onVersionChangeRequest,
    SdbOnBlockedCallback? onBlocked,
  }) => _SdbOpenDatabaseOptions(
    version: version,
    schema: schema,
    onVersionChange: onVersionChange,
    codec: codec,
    closeOnVersionChange: closeOnVersionChange,
    onVersionChangeRequest: onVersionChangeRequest,
    onBlocked: onBlocked,
  );

  /// The version of the database.
  int? get version;

  /// The schema of the database.
  SdbDatabaseSchema? get schema;

  /// provide onVersionChange to handle schema changes or initialization
  /// manually, this is called after automatic schema change
  SdbOnVersionChangeCallback? get onVersionChange;

  /// Codec used
  SdbCodec? get codec;

  /// Whether the database closes itself when another connection (another
  /// tab, an iframe, or this page) opens it at a higher version or deletes
  /// it, the IndexedDB `versionchange` event. `true` when null.
  ///
  /// Closing lets the other open complete instead of staying blocked, the
  /// spec behaviour; this database is then no longer usable
  /// ([SdbDatabase.isClosed], its operations throw), the app should reload.
  /// [onVersionChangeRequest] is called first. Only the browser fires the
  /// event; io and memory databases never see it.
  bool? get closeOnVersionChange;

  /// Called when another connection opens the database at a higher version
  /// or deletes it, before the close of [closeOnVersionChange]. Tell the
  /// user a newer version runs elsewhere and to reload. Synchronous, do not
  /// await anything to delay the close.
  SdbOnVersionChangeRequestCallback? get onVersionChangeRequest;

  /// Called when the open waits for another connection that keeps the
  /// database open at a lower version and does not close on `versionchange`
  /// (a tab of an older version of the app). The open keeps waiting and
  /// completes once that connection closes: use it to tell the user to close
  /// the other tabs. Never called for io and memory databases.
  SdbOnBlockedCallback? get onBlocked;

  /// Copy with new values.
  SdbOpenDatabaseOptions copyWith({
    int? version,
    SdbDatabaseSchema? schema,
    SdbOnVersionChangeCallback? onVersionChange,
    SdbCodec? codec,
    bool? closeOnVersionChange,
    SdbOnVersionChangeRequestCallback? onVersionChangeRequest,
    SdbOnBlockedCallback? onBlocked,
  });
}

/// Options for opening a Sdb database.
class _SdbOpenDatabaseOptions implements SdbOpenDatabaseOptions {
  /// Options for opening a Sdb database.
  _SdbOpenDatabaseOptions({
    this.version,
    this.schema,
    this.onVersionChange,
    this.codec,
    this.closeOnVersionChange,
    this.onVersionChangeRequest,
    this.onBlocked,
  });
  @override
  SdbOpenDatabaseOptions copyWith({
    int? version,
    SdbDatabaseSchema? schema,
    SdbOnVersionChangeCallback? onVersionChange,
    SdbCodec? codec,
    bool? closeOnVersionChange,
    SdbOnVersionChangeRequestCallback? onVersionChangeRequest,
    SdbOnBlockedCallback? onBlocked,
  }) {
    return _SdbOpenDatabaseOptions(
      version: version ?? this.version,
      schema: schema ?? this.schema,
      onVersionChange: onVersionChange ?? this.onVersionChange,
      codec: codec ?? this.codec,
      closeOnVersionChange: closeOnVersionChange ?? this.closeOnVersionChange,
      onVersionChangeRequest:
          onVersionChangeRequest ?? this.onVersionChangeRequest,
      onBlocked: onBlocked ?? this.onBlocked,
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

  /// Codec used, default to SdbCodec.defaultCodec
  @override
  final SdbCodec? codec;

  @override
  final bool? closeOnVersionChange;

  @override
  final SdbOnVersionChangeRequestCallback? onVersionChangeRequest;

  @override
  final SdbOnBlockedCallback? onBlocked;
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

    /// Compat, version
    @Deprecated('Use options instead') int? version,

    /// Compat, onVersionChange
    @Deprecated('Use options instead')
    SdbOnVersionChangeCallback? onVersionChange,

    /// Compat, schema
    @Deprecated('Use options instead') SdbDatabaseSchema? schema,
  });

  /// Delete a database.
  Future<void> deleteDatabase(String name);
}

/// Sdb Factory private extension.
extension SdbFactoryPrvExtension on SdbFactory {
  /// Internal impl
  SdbFactoryIdb get factoryIdb => this as SdbFactoryIdb;
}

/// Sdb Factory extension.
extension SdbFactoryExtension on SdbFactory {
  SdbFactoryIdb get _factoryIdb => factoryIdb;

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

    /// Compat
    @Deprecated('Use options instead') int? version,
    @Deprecated('Use options instead')
    /// Compat
    SdbOnVersionChangeCallback? onVersionChange,
  }) async {
    Future<SdbDatabase> doOpen() {
      return openDatabase(
        name,
        options: options,
        // ignore: deprecated_member_use_from_same_package
        version: version,
        // ignore: deprecated_member_use_from_same_package
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
      print(
        'openOnDowngradeDelete(=> $version, $name)}: error ${e.runtimeType} $e, trying opening',
      );

      /// There is no good way to detect a downgrade, try to open without version to check the version
      var db = await openDatabase(name);
      var isDowngrade = version < db.version;
      // ignore: avoid_print
      print(
        'openOnDowngradeDelete(${db.version} => $version)}${isDowngrade ? ' downgrade deleting $name' : ' not expected'}',
      );
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
