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
  void checkOpenArguments(
      {int version, OnUpgradeNeededFunction onUpgradeNeeded}) {
    // check params
    if (((version != null) || (onUpgradeNeeded != null)) &&
        ((version == null) || (onUpgradeNeeded == null))) {
      throw ArgumentError(
          'version and onUpgradeNeeded must be specified together');
    }
    if (version == 0) {
      throw ArgumentError('version cannot be 0');
    }
  }

  /// Whether key as double are supported
  bool get supportsDoubleKey;
}
