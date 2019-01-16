library idb_shim_memory;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_memory.dart';

/// The in-memory factory
IdbFactory get idbMemoryFactory => IdbFactorySembast(memoryDatabaseFactory);

/// Special factory in memory but supporting writing on a virtual file system (in memory too)
IdbFactory get idbMemoryFsFactory => IdbFactorySembast(memoryFsDatabaseFactory);
