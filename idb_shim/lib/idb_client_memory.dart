library idb_shim_memory;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_memory.dart';

/// The in-memory factory
/// IdbFactory get idbFactoryMemory => IdbFactorySembast(databaseFactoryMemory);

/// Special factory in memory but supporting writing on a virtual file system (in memory too)
IdbFactory get idbFactoryMemoryFs => IdbFactorySembast(databaseFactoryMemoryFs);

/// @deprecated v3
// @deprecated v3
IdbFactory get idbMemoryFactory => idbFactoryMemory;

/// The in-memory factory
IdbFactory get idbFactoryMemory => IdbFactorySembast(databaseFactoryMemory);

/// @deprecated v3
/// Special factory in memory but supporting writing on a virtual file system (in memory too)
IdbFactory get idbMemoryFsFactory => idbFactoryMemoryFs;
