import 'sdb.dart';

/// Sdb Factory
abstract class SdbFactory implements SdbFactoryInterface {}

/// Mixin helper
mixin SdbFactoryDefaultMixin implements SdbFactory {
  @override
  Future<SdbDatabase> openDatabase(
    String name, {
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
  }) {
    throw UnsupportedError('openDatabase');
  }

  @override
  Future<void> deleteDatabase(String name) async {
    throw UnsupportedError('deleteDatabase');
  }
}

/// Sdb Factory interface.
abstract class SdbFactoryInterface {
  /// Open a database.
  Future<SdbDatabase> openDatabase(
    String name, {
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
  });

  /// Delete a database.
  Future<void> deleteDatabase(String name);
}

/// Sdb Factory extension.
extension SdbFactoryExtension on SdbFactory {
  /*
  SdbFactoryImpl get _impl => this as SdbFactoryImpl;

  /// [version] must be > 0
  Future<SdbDatabase> openDatabase(
    String name, {
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
  }) {
    return _impl.openDatabaseImpl(name, version, onVersionChange);
  }

  /// [version] must be > 0
  Future<void> deleteDatabase(String name) async {
    await _impl.deleteDatabaseImpl(name);
  }*/
}
