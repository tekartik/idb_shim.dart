/// The IndexedDB API on every platform, the main import.
///
/// Gives the whole idb API (`IdbFactory`, `Database`, `Transaction`,
/// `ObjectStore`, `Index`, `KeyRange`, cursors) and the factories available
/// everywhere: the browser ones ([idbFactoryWeb], [idbFactoryWebWorker],
/// which throw when used outside the web) and the in memory ones
/// ([newIdbFactoryMemory], [idbFactoryMemory]). The Dart VM file based
/// factory is in `package:idb_shim/idb_io.dart`, the SQLite one in
/// `package:idb_sqflite`.
///
/// ```dart
/// var db = await newIdbFactoryMemory().open(
///   'my_app.db',
///   version: 1,
///   onUpgradeNeeded: (event) {
///     event.database.createObjectStore('users', autoIncrement: true);
///   },
/// );
/// ```
library;

export 'idb.dart';
export 'idb_client_memory.dart'
    show idbFactoryMemory, idbFactoryMemoryFs, newIdbFactoryMemory;
export 'src/native_web/idb_native.dart'
    show
        idbFactoryNative,
        idbFactoryWeb,
        idbFactoryWebSupported,
        idbFactoryWebWorker,
        idbFactoryWebWorkerSupported;
