library idb_shim_browser;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client_native.dart';

export 'package:idb_shim/idb_client_memory.dart'
    show idbFactoryMemory, idbMemoryFactory;
export 'package:idb_shim/idb_client_native.dart'
    show idbFactoryNative, idbNativeFactory;
export 'package:idb_shim/src/browser/browser_compat.dart';

/// Get a factory by name.
///
/// Not recommended.
IdbFactory? getIdbFactory([String? name]) {
  name ??= idbFactoryNameBrowser;

  switch (name) {
    case idbFactoryNameBrowser:
      return idbFactoryNative;
    case idbFactoryNamePersistent:
      return idbFactoryNative;
    case idbFactoryNameNative:
      return idbFactoryNative;
    case idbFactoryNameWebSql:
      return null;
    case idbFactoryNameMemory:
    case idbFactoryNameSembastMemory:
      return idbFactoryMemory;
    default:
      throw UnsupportedError("Factory '$name' not supported");
  }
}

///
/// this uses indexeddb is supported.
/// defaulting to memory
///
IdbFactory get idbFactoryBrowser {
  var idbFactory = idbFactoryNative;
  idbFactory ??= idbFactoryMemory;

  return idbFactory;
}
