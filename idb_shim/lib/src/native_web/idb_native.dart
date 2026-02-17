import 'package:idb_shim/idb.dart';

import 'idb_native_stub.dart'
    if (dart.library.js_interop) 'idb_native_web.dart';

export 'idb_native_stub.dart'
    if (dart.library.js_interop) 'idb_native_web.dart';

/// Wrap the window/service worker implementation
///
/// [nativeIdbFactory] can be html.window.indexedDB for browser app, for
/// service worker you can use self.indexedDB
IdbFactory idbFactoryFromIndexedDB(dynamic nativeIdbFactory) =>
    idbFactoryFromIndexedDBImpl(nativeIdbFactory);
