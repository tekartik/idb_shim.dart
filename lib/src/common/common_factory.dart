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
}
