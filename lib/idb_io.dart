library idb_shim.io;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

IdbFactory get idbMemoryFactory => idbSembastMemoryFactory;

IdbFactory _idbSembastMemoryFactory;
IdbFactory get idbSembastMemoryFactory {
  if (_idbSembastMemoryFactory == null) {
    _idbSembastMemoryFactory =
        new IdbSembastFactory(memoryDatabaseFactory, null);
  }
  return _idbSembastMemoryFactory;
}

IdbFactory getIdbSembastIoFactory(String path) =>
    new IdbSembastFactory(databaseFactoryIo, path);

/// do no use
/// choose manually
@deprecated
IdbFactory getIdbFactory({String name, String path}) {
  if (name == null) {
    name = idbFactoryPersistent;
  }
  switch (name) {
    case idbFactorySembastMemory:
    case idbFactoryMemory:
      return idbSembastMemoryFactory;
    case idbFactorySembastIo:
    case idbFactoryIo:
      return getIdbSembastIoFactory(path);
    case idbFactoryPersistent:
      return getIdbPersistentFactory(path);
    case idbFactoryMemory:
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
