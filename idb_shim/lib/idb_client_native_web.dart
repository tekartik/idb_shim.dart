/// New implementation base on web package. wasm compatible
///
/// {@canonicalFor idb_shim.src.native_web.idb_native_web.idbFactoryFromIndexedDB}
library idb_shim.native_web;

export 'package:idb_shim/src/native_web/idb_native.dart'
    show idbFactoryNative, idbFactoryNativeSupported, idbFactoryFromIndexedDB;
