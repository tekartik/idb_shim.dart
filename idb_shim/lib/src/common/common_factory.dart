// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_value.dart';

abstract class IdbFactoryBase implements IdbFactory {
  ///
  /// When a factory is created, mark it as supported
  ///
  IdbFactoryBase() {
    IdbFactoryBase.supported = true;
  }

  static bool supported = false;

  // common implementation
  @override
  int cmp(Object first, Object second) => compareKeys(first, second);

  /// Check open arguments
  void checkOpenArguments({
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
  }) {
    /// this does crash in native so keep it here too for all implementations
    if (version == 0) {
      throw ArgumentError('version cannot be 0');
    }
  }

  /// Whether key as double are supported
  bool get supportsDoubleKey;
}

/// Helper extension
extension IdbFactoryExt on IdbFactory {
  /// Open a database and delete in case of downgrade.
  Future<Database> openOnDowngradeDelete(
    String name, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) async {
    Future<Database> doOpen() {
      return open(
        name,
        version: version,
        onUpgradeNeeded: onUpgradeNeeded,
        onBlocked: onBlocked,
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
      var db = await open(name);
      var isDowngrade = version < db.version;
      db.close();

      if (isDowngrade) {
        await deleteDatabase(name);
      } else {
        rethrow;
      }
      return await doOpen();
    }
  }
}
