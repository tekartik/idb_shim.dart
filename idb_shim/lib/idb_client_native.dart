library idb_shim_native;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/native/native_factory.dart';

export 'package:idb_shim/src/native/native_compat.dart';

/// The native factory
///
/// To use instead of html.window.indexedDB but provides the same API.
///
/// Is null if IndexedDB is not supported
IdbFactory get idbFactoryNative => idbFactoryNativeImpl;
