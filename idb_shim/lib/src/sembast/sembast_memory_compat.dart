import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_memory.dart';

@Deprecated('use idbFactoryMemory')
IdbFactory get idbMemoryFactory => idbFactoryMemory;

@Deprecated('use idbFactoryMemoryFs')
IdbFactory get idbMemoryFsFactory => idbFactoryMemoryFs;