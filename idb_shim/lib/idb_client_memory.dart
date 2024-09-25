/// In memory implementation.
/// {@canonicalFor sembast_memory_compat.idbMemoryFactory}
library idb_shim.memory;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/sembast/sembast_factory.dart';
export 'idb_shim.dart';

/// Special factory in memory but supporting writing on a virtual file system (in memory too)
IdbFactory get idbFactoryMemoryFs => idbFactorySembastMemoryFsImpl;

/// The in-memory factory
IdbFactory get idbFactoryMemory => idbFactorySembastMemoryImpl;

/// An empty in-memory factory, good for unit test.
IdbFactory newIdbFactoryMemory() => newIdbFactorySembastMemoryImpl();
