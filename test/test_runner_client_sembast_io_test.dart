@TestOn("vm")
library idb_shim.test_runner_sembast_io;

import 'test_runner.dart';
import 'idb_io_test_common.dart';

void main() {
  IoTestContext ctx = new IoTestContext();
  defineTests(ctx.factory);
  defineTests_(ctx);
}
