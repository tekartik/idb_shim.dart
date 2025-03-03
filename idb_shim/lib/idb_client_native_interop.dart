/// New implementation base on web package. wasm compatible
///
/// {@canonicalFor idb_shim.src.native_web.idb_native_web.idbFactoryFromIndexedDB}
library;

export 'package:idb_shim/src/native_web/idb_native.dart'
    show
        idbFactoryWeb,
        idbFactoryWebWorker,
        idbFactoryNative,
        idbFactoryNativeSupported,
        idbFactoryWebSupported,
        idbFactoryFromIndexedDB;
