/// Legacy API
@Deprecated('2026-04-01: Use idb_client_native.dart')
library;

import 'package:idb_shim/src/utils/unimplemented_stub.dart';

import 'idb_client_native_interop.dart' as interop;
import 'idb_shim.dart';

export 'idb_shim.dart';

/// Deprecated implementation
@Deprecated('Use idbFactoryNative from idb_client_native_interop')
IdbFactory get idbFactoryNative => interop.idbFactoryNative;

/// Deprecated implementation
@Deprecated('Use idbFactoryNativeSupported from idb_client_native_interop')
bool get idbFactoryNativeSupported => interop.idbFactoryNativeSupported;

/// Deprecated implementation
@Deprecated('Use idbFactoryFromIndexedDB from idb_client_native_interop')
IdbFactory idbFactoryFromIndexedDB(dynamic nativeIdbFactory) =>
    idbUnimplementedStub('idbFactoryFromIndexedDB');
