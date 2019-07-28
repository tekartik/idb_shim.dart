library idb_shim_native;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/native/native_factory.dart';

/// The native factory
///
/// @v2 deprecated
/// will be named idbFactoryNative
IdbFactory get idbNativeFactory => IdbFactoryNativeImpl();

IdbFactory get idbFactoryNativeV2 => IdbFactoryNativeImpl();

// The native factory
// IdbFactory get idbFactoryNative => IdbFactoryNativeImpl();

/// @v2 deprecated, use idbFactoryNative
abstract class IdbNativeFactory extends IdbFactory {
  /// True if supported
  static bool get supported {
    return IdbFactoryNativeImpl.supported;
  }

  /// @v2 deprecated, use idbFactoryNative
  factory IdbNativeFactory() => IdbFactoryNativeImpl();
}

/// Indexed db native factory
abstract class IdbFactoryNative implements IdbFactory {
  /// True if supported
  static bool get supported {
    return IdbFactoryNativeImpl.supported;
  }
}
