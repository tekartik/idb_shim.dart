library idb_shim.test_runner_sembast_io;

import 'test_runner.dart' as test_runner;

import 'package:idb_shim/idb_client.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:idb_shim/idb_client_sembast.dart';

void main() {
  IdbFactory idbFactory = new IdbSembastFactory(memoryDatabaseFactory);
  test_runner.defineTests(idbFactory);
}
