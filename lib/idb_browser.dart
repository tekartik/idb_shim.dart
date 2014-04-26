library idb_browser_new;

import 'package:tekartik_idb/idb_client_native.dart';
import 'package:tekartik_idb/idb_client_websql.dart';
import 'package:tekartik_idb/idb_client_memory.dart';
import 'package:tekartik_idb/idb_client.dart';

IdbFactory get idbWebSqlFactory {
  return new IdbWebSqlFactory();
}

IdbFactory get idbNativeFactory {
  return new IdbNativeFactory();
}

IdbFactory get idbMemoryFactory {
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