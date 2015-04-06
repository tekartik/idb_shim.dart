library idb_shim.io;

import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

IdbFactory get idbMemoryFactory => idbSembastMemoryFactory;

@deprecated
IdbFactory get idbMemoryOldFactory {
  return new IdbMemoryFactory();
}

IdbFactory _idbSembastMemoryFactory;
IdbFactory get idbSembastMemoryFactory {
  if (_idbSembastMemoryFactory == null) {
    _idbSembastMemoryFactory = new IdbSembastFactory(memoryDatabaseFactory, null);
  }
  return _idbSembastMemoryFactory;
}

IdbFactory _idbSembastIoFactory;
IdbFactory getIdbSembastIoFactory(String path) {
  if (_idbSembastIoFactory == null) {
    _idbSembastIoFactory = new IdbSembastFactory(ioDatabaseFactory, path);
  }
  return _idbSembastIoFactory;
}

IdbFactory getIdbFactory([String name, String path]) {
  if (name == null) {
    name = IDB_FACTORY_BROWSER;
  }
  switch (name) {
    case IDB_FACTORY_SEMBAST_MEMORY:
      return idbSembastMemoryFactory;
    case IDB_FACTORY_SEMBAST_IO:
      return getIdbSembastIoFactory(path);
    case IDB_FACTORY_PERSISTENT:
      return getIdbPersistentFactory(path);
    case IDB_FACTORY_MEMORY:
      return idbMemoryFactory;
    default:
      throw new UnsupportedError("Factory '$name' not supported");
  }
}

///
/// Only sembast io is persistent
///
IdbFactory getIdbPersistentFactory(String path) {
  return getIdbSembastIoFactory(path);
}
