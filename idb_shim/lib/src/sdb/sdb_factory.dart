import 'sdb.dart';
import 'sdb_factory_impl.dart';

/// Sdb Factory
abstract class SdbFactory {}

/// Sdb Factory extension.
extension SdbFactoryExtension on SdbFactory {
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
  }
}
