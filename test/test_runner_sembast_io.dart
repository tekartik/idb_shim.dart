library idb_shim.test_runner_sembast_io;

import 'package:tekartik_test/test_config_io.dart';
import 'test_runner.dart';

import 'package:idb_shim/idb_client.dart';
import 'package:sembast/sembast_io.dart';
import 'package:idb_shim/idb_client_sembast.dart';

void main() {
  useVMConfiguration();
  IdbFactory idbFactory = new IdbSembastFactory(ioDatabaseFactory, "tmp");
  defineTests(idbFactory);
}