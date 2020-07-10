export 'idb_native_stub.dart'
    if (dart.library.html) 'idb_native_web.dart'
    if (dart.library.io) 'idb_native_io.dart';
