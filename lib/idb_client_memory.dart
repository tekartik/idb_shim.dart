library idb_shim_memory;

import 'package:idb_shim/idb_client.dart';

import 'package:sembast/sembast_memory.dart';
import 'package:idb_shim/idb_client_sembast.dart';

IdbFactory get idbMemoryFactory => new IdbSembastFactory(memoryDatabaseFactory);
