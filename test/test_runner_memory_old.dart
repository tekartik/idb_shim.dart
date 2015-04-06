library all_test_console;

import 'package:tekartik_test/test_config_io.dart';
import 'idb_test_common.dart' as test;
import 'test_runner.dart';

void main() {
  useVMConfiguration();
  defineTests(test.idbTestMemoryOldFactory);
}
