library idb_shim_browser;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_shim/idb_client_websql.dart';
import 'package:sembast/sembast_memory.dart' as sembast;

export 'package:idb_shim/idb_client_memory.dart'
    show idbFactoryMemory, idbMemoryFactory;
export 'package:idb_shim/idb_client_native.dart'
    show idbFactoryNative, idbNativeFactory;

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
      return idbFactoryNative;
    // ignore: deprecated_member_use_from_same_package
    case idbFactoryNameWebSql:
      // ignore: deprecated_member_use_from_same_package
      return idbFactoryWebSql;
    case idbFactoryNameMemory:
    case idbFactoryNameSembastMemory:
      return idbFactoryMemory;
    default:
      throw UnsupportedError("Factory '$name' not supported");
  }
}

@deprecated
IdbFactory get idbFactoryWebSql {
  if (IdbWebSqlFactory.supported) {
    return IdbWebSqlFactory();
  } else {
    return null;
  }
}

@deprecated // v2
IdbFactory get idbWebSqlFactory => idbFactoryWebSql;

IdbFactory _idbSembastMemoryFactory;

@deprecated // v2
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
  IdbFactory idbFactory = IdbFactoryNative.supported ? idbFactoryNative : null;
  if (idbFactory == null) {
    // ignore: deprecated_member_use_from_same_package
    idbFactory = idbFactoryWebSql;
  }
  return idbFactory;
}

///
/// this use the best implementation available
/// defaulting to memory
///
IdbFactory get idbFactoryBrowser {
  IdbFactory idbFactory = idbPersistentFactory;
  if (idbFactory == null) {
    idbFactory = idbFactoryMemory;
  }
  return idbFactory;
}

// @deprecated // v3
IdbFactory get idbBrowserFactory => idbFactoryBrowser;
