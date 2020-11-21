import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_memory.dart' as sembast;

IdbFactory? _idbSembastMemoryFactory;

/// Deprecated.
@deprecated
IdbFactory get idbSembastMemoryFactory {
  _idbSembastMemoryFactory ??=
      IdbFactorySembast(sembast.databaseFactoryMemory, null);

  return _idbSembastMemoryFactory!;
}

///
/// Use native indexeddb if supported.
///
/// This can return null;
///
@deprecated
IdbFactory get idbPersistentFactory => idbFactoryNative;

/// Deprecated.
@Deprecated('Use idbFactoryBrowser')
IdbFactory get idbBrowserFactory => idbFactoryBrowser;
