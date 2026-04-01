import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_shim/idb_sdb.dart';
import 'package:meta/meta.dart';

/// Sdb Factory logger type.
typedef SdbFactoryLoggerType = IdbFactoryLoggerType;

/// Sdb Factory logger extension.
extension SdbFactoryLoggerExtension on SdbFactory {
  /// Quick logger wrapper, useful in unit test or dev mode.
  ///
  /// sdbFactory = sdbFactory.debugWrapInLogger()
  ///
  /// [maxLogCount] optional, warning global setting
  @doNotSubmit
  SdbFactory debugWrapInLogger({
    SdbFactoryLoggerType type = SdbFactoryLoggerType.all,
    int? maxLogCount,
  }) {
    return sdbFactoryFromIdb(
      // ignore: deprecated_member_use_from_same_package
      idbFactory.debugWrapInLogger(type: type, maxLogCount: maxLogCount),
    );
  }
}
