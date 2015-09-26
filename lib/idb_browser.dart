library idb_shim_browser;

import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_websql.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_memory.dart' as sembast;
import 'package:idb_shim/idb_client.dart';

IdbFactory getIdbFactory([String name]) {
  if (name == null) {
    name = idbFactoryBrowser;
  }
  switch (name) {
    case idbFactoryBrowser:
      return idbBrowserFactory;
    case idbFactoryPersistent:
      return idbPersistentFactory;
    case idbFactoryNative:
      return idbNativeFactory;
    case idbFactoryWebSql:
      return idbWebSqlFactory;
    case idbFactoryMemory:
      return idbMemoryFactory;
    case idbFactorySembastMemory:
    case idbFactoryMemory:
      return idbSembastMemoryFactory;
    default:
      throw new UnsupportedError("Factory '$name' not supported");
  }
}

IdbFactory get idbWebSqlFactory {
  if (IdbWebSqlFactory.supported) {
    return new IdbWebSqlFactory();
  } else {
    return null;
  }
}

IdbFactory get idbNativeFactory {
  if (IdbNativeFactory.supported) {
    return new IdbNativeFactory();
  } else {
    return null;
  }
}

IdbFactory get idbMemoryFactory => idbSembastMemoryFactory;

IdbFactory _idbSembastMemoryFactory;
IdbFactory get idbSembastMemoryFactory {
  if (_idbSembastMemoryFactory == null) {
    _idbSembastMemoryFactory =
        new IdbSembastFactory(sembast.memoryDatabaseFactory, null);
  }
  return _idbSembastMemoryFactory;
}

/**
 * Use either native (indexeddb) or websql implementation
 * This means that the memory implementation won't be linked
 * if you use this function
 * This can return null;
 */
IdbFactory get idbPersistentFactory {
  IdbFactory idbFactory = idbNativeFactory;
  if (idbFactory == null) {
    idbFactory = idbWebSqlFactory;
  }
  return idbFactory;
}

/**
 * this use the best implementation available
 * defaulting to memory
 */
IdbFactory get idbBrowserFactory {
  IdbFactory idbFactory = idbPersistentFactory;
  if (idbFactory == null) {
    idbFactory = idbMemoryFactory;
  }
  return idbFactory;
}
