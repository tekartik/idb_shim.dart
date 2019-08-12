library idb_shim_memory;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_memory.dart';

/// The in-memory factory
/// IdbFactory get idbFactoryMemory => IdbFactorySembast(databaseFactoryMemory);

/// Special factory in memory but supporting writing on a virtual file system (in memory too)
IdbFactory get idbFactoryMemoryFs => IdbFactorySembast(databaseFactoryMemoryFs);

/// @deprecated v2
/// The in-memory factory
IdbFactory get idbMemoryFactory => IdbFactorySembast(databaseFactoryMemory);

/// @deprecated v2
/// Special factory in memory but supporting writing on a virtual file system (in memory too)
IdbFactory get idbMemoryFsFactory => idbFactoryMemoryFs;
