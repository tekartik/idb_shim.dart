library idb_shim.io;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

/// In memory factory
/// IdbFactory get idbFactoryMemory => idbSembastMemoryFactory;

/// @deprecated v2
IdbFactory get idbMemoryFactory => idbSembastMemoryFactory;

IdbFactory _idbSembastMemoryFactory;

/// @deprecated v2
IdbFactory get idbSembastMemoryFactory => idbFactorySembastMemoryV2;

/// Sembast memory based factory
IdbFactory get idbFactorySembastMemoryV2 {
  if (_idbSembastMemoryFactory == null) {
    _idbSembastMemoryFactory = IdbFactorySembast(databaseFactoryMemory, null);
  }
  return _idbSembastMemoryFactory;
}

/// @deprecated v2
IdbFactory getIdbSembastIoFactory(String path) => getIdbFactorySembastIo(path);

/// Get an io base factory from the defined root path
IdbFactory getIdbFactorySembastIo(String path) =>
    IdbFactorySembast(databaseFactoryIo, path);

/// do no use
/// choose manually
@deprecated
IdbFactory getIdbFactory({String name, String path}) {
  if (name == null) {
    name = idbFactoryPersistent;
  }
  switch (name) {
    case idbFactoryNameSembastMemory:
    case idbFactoryNameMemory:
      return idbSembastMemoryFactory;
    case idbFactoryNameSembastIo:
    case idbFactoryNameIo:
      return getIdbSembastIoFactory(path);
    case idbFactoryNamePersistent:
      return getIdbPersistentFactory(path);
    default:
      throw UnsupportedError("Factory '$name' not supported");
  }
}

///
/// Only sembast io is persistent
///
IdbFactory getIdbPersistentFactory(String path) =>
    getIdbFactoryPersistent(path);

///
/// Only sembast io is persistent
///
IdbFactory getIdbFactoryPersistent(String path) {
  return getIdbSembastIoFactory(path);
}
