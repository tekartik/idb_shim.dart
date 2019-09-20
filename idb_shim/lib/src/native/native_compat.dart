// Deprecate since V2, will be removed
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/src/native/native_factory.dart';

@Deprecated('Use idbFactoryNative instead')
IdbFactory get idbNativeFactory => idbFactoryNative;

@Deprecated('Use idbFactoryNative instead')
IdbFactory get idbFactoryNativeV2 => idbFactoryNative;

// The native factory
// IdbFactory get idbFactoryNative => IdbFactoryNativeImpl();

@Deprecated('Use idbFactoryNative instead')
abstract class IdbNativeFactory extends IdbFactory {
  /// True if supported
  static bool get supported {
    return IdbFactoryNativeImpl.supported;
  }

  @Deprecated('Use idbFactoryNative instead')
  factory IdbNativeFactory() => IdbFactoryNativeImpl();
}

/// Indexed db native factory
@deprecated
abstract class IdbFactoryNative implements IdbFactory {
  /// True if supported
  @Deprecated('idbFactoryNative is null if not supported')
  static bool get supported {
    return IdbFactoryNativeImpl.supported;
  }
}
