library idb_console;

import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client.dart';

IdbFactory get idbMemoryFactory {
  return new IdbMemoryFactory();
}