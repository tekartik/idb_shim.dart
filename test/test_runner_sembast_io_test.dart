@TestOn("vm")

library idb_shim.test_runner_sembast_io;

import 'package:test/test.dart';
import 'test_runner.dart';

import 'package:idb_shim/idb_client.dart';
import 'package:sembast/sembast_io.dart';
import 'package:idb_shim/idb_client_sembast.dart';

void main() {
  //useVMConfiguration();
  IdbFactory idbFactory = new IdbSembastFactory(ioDatabaseFactory, "tmp");
  defineTests(idbFactory);
}