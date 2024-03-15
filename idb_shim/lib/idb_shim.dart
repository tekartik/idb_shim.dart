/// {@canonicalFor idb_shim.error.DatabaseIndexNotFoundError}
/// {@canonicalFor idb_shim.error.DatabaseInvalidKeyError}
/// {@canonicalFor idb_shim.error.DatabaseNoKeyError}
/// {@canonicalFor idb_shim.error.DatabaseReadOnlyError}
/// {@canonicalFor idb_shim.error.DatabaseStoreNotFoundError}
/// {@canonicalFor idb_shim.error.DatabaseTransactionStoreNotFoundError}
library idb_shim;

export 'idb.dart';
export 'idb_client_memory.dart' show idbFactoryMemory, idbFactoryMemoryFs;
export 'src/native_web/idb_native.dart' show idbFactoryNative;
