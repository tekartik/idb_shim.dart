library idb_console;

import 'package:tekartik_idb/idb_client_memory.dart';
import 'package:tekartik_idb/idb_client.dart';

IdbFactory get idbMemoryFactory {
  return new IdbMemoryFactory();
}