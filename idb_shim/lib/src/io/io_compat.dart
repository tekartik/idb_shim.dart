import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_io.dart';

@deprecated
IdbFactory get idbSembastMemoryFactory => idbFactorySembastMemory;

/// do not use
/// choose manually
@deprecated
IdbFactory getIdbFactory({String name, String path}) {
  if (name == null) {
    name = idbFactoryNamePersistent;
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

@deprecated
IdbFactory getIdbSembastIoFactory(String path) => getIdbFactorySembastIo(path);

@Deprecated('use getIdbFactoryPersistent instead')
IdbFactory getIdbPersistentFactory(String path) =>
    getIdbFactoryPersistent(path);
