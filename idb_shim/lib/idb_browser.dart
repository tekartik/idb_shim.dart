library idb_shim_browser;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_shim/idb_client_websql.dart';
import 'package:sembast/sembast_memory.dart' as sembast;

IdbFactory getIdbFactory([String name]) {
  if (name == null) {
    name = idbFactoryNameBrowser;
  }
  switch (name) {
    case idbFactoryNameBrowser:
      return idbBrowserFactory;
    case idbFactoryNamePersistent:
      return idbPersistentFactory;
    case idbFactoryNameNative:
      return idbNativeFactory;
    // ignore: deprecated_member_use_from_same_package
    case idbFactoryWebSql:
      return idbWebSqlFactory;
    case idbFactoryNameMemory:
      return idbMemoryFactory;
    case idbFactoryNameSembastMemory:
      return idbSembastMemoryFactory;
    default:
      throw UnsupportedError("Factory '$name' not supported");
  }
}

IdbFactory get idbWebSqlFactory {
  if (IdbWebSqlFactory.supported) {
    return IdbWebSqlFactory();
  } else {
    return null;
  }
}

IdbFactory get idbNativeFactory {
  if (IdbFactoryNative.supported) {
    return IdbNativeFactory();
  } else {
    return null;
  }
}

IdbFactory get idbMemoryFactory => idbSembastMemoryFactory;

IdbFactory _idbSembastMemoryFactory;

IdbFactory get idbSembastMemoryFactory {
  if (_idbSembastMemoryFactory == null) {
    _idbSembastMemoryFactory =
        IdbFactorySembast(sembast.databaseFactoryMemory, null);
  }
  return _idbSembastMemoryFactory;
}

///
/// Use either native (indexeddb) or websql implementation
/// This means that the memory implementation won't be linked
/// if you use this function
/// This can return null;
///
IdbFactory get idbPersistentFactory {
  IdbFactory idbFactory = idbNativeFactory;
  if (idbFactory == null) {
    idbFactory = idbWebSqlFactory;
  }
  return idbFactory;
}

///
/// this use the best implementation available
/// defaulting to memory
///
IdbFactory get idbBrowserFactory {
  IdbFactory idbFactory = idbPersistentFactory;
  if (idbFactory == null) {
    idbFactory = idbMemoryFactory;
  }
  return idbFactory;
}
