library idb_shim_memory;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/sembast/sembast_factory.dart';

export 'package:idb_shim/src/sembast/sembast_memory_compat.dart';

/// Special factory in memory but supporting writing on a virtual file system (in memory too)
IdbFactory get idbFactoryMemoryFs => idbFactorySembastMemoryFsImpl;

/// The in-memory factory
IdbFactory get idbFactoryMemory => idbFactorySembastMemoryImpl;
