/// {@canonicalFor idb_shim.src.native.idb_native_web.idbFactoryFromIndexedDB}
/// Legacy version using dart:html not wasm compatible
library idb_shim_native_html;

export 'package:idb_shim/src/native/idb_native.dart'
    show idbFactoryNative, idbFactoryNativeSupported, idbFactoryFromIndexedDB;
