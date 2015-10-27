@TestOn("vm")
library idb_shim.test_runner_sembast_io;

import 'test_runner.dart' as test_runner;
import 'idb_test_common.dart';

void main() {
  defineTests(idbMemoryFsContext);
}

defineTests(SembastFsTestContext idbFsContext) {
  test_runner.defineTests(idbFsContext);
}
