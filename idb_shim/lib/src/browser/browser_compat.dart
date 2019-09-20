import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_shim/src/websql/websql_compat.dart';
import 'package:sembast/sembast_memory.dart' as sembast;

IdbFactory _idbSembastMemoryFactory;

@deprecated
IdbFactory get idbSembastMemoryFactory {
  if (_idbSembastMemoryFactory == null) {
    _idbSembastMemoryFactory =
        IdbFactorySembast(sembast.databaseFactoryMemory, null);
  }
  return _idbSembastMemoryFactory;
}

///
/// Use native indexeddb if supported.
///
/// This can return null;
///
@deprecated
IdbFactory get idbPersistentFactory {
  var idbFactory = idbFactoryNative;
  if (idbFactory == null) {
    // ignore: deprecated_member_use_from_same_package
    idbFactory = idbFactoryWebSql;
  }
  return idbFactory;
}

@Deprecated('Use idbFactoryBrowser')
IdbFactory get idbBrowserFactory => idbFactoryBrowser;
