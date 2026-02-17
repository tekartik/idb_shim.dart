/// New implementation base on web package. wasm compatible
///
/// @nodoc
library;

export 'package:idb_shim/src/native_web/idb_native.dart'
    show
        idbFactoryWeb,
        idbFactoryWebWorker,
        idbFactoryNative,
        idbFactoryNativeSupported,
        idbFactoryWebSupported,
        idbFactoryFromIndexedDB;
