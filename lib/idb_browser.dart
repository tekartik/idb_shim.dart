library idb_browser;

import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_websql.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client.dart';

IdbFactory getIdbFactory([String name]) {
  if (name == null) {
    name = IDB_FACTORY_BROWSER;
  }
  switch (name) {
    case IDB_FACTORY_BROWSER:
      return idbBrowserFactory;
    case IDB_FACTORY_PERSISTENT:
      return idbPersistentFactory;
    case IDB_FACTORY_NATIVE:
      return idbNativeFactory;
    case IDB_FACTORY_WEBSQL:
      return idbWebSqlFactory;
    case IDB_FACTORY_MEMORY:
      return idbMemoryFactory;
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

IdbFactory get idbMemoryFactory {
  // always supported
  return new IdbMemoryFactory();
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
