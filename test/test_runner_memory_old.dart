library all_test_console;

import 'package:tekartik_test/test_config_io.dart';
import 'idb_test_common.dart' as test;
import 'test_runner.dart';
import 'package:idb_shim/idb_io.dart';

void main() {
  useVMConfiguration();
  defineTests(test.idbTestMemoryFactory);
}
