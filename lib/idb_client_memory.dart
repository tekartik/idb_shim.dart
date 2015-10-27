library idb_shim_memory;

import 'package:idb_shim/idb_client.dart';

import 'package:sembast/sembast_memory.dart';
import 'package:idb_shim/idb_client_sembast.dart';

/// The in-memory factory
IdbFactory get idbMemoryFactory => new IdbSembastFactory(memoryDatabaseFactory);

/// Special factory in memory but supporting writing on a virtual file system (in memory too)
IdbFactory get idbMemoryFsFactory =>
    new IdbSembastFactory(memoryFsDatabaseFactory);
