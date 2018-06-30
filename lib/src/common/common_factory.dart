import 'package:idb_shim/idb.dart';

abstract class IdbFactoryBase implements IdbFactory {
  ///
  /// When a factory is created, mark it as supported
  ///
  IdbFactoryBase() {
    IdbFactoryBase.supported = true;
  }

  static bool supported = false;
}
