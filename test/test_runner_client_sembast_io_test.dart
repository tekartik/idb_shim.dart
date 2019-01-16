@TestOn("vm")
library idb_shim.test_runner_sembast_io;

import 'idb_io_test_common.dart';
import 'test_runner_client_sembast_fs_test.dart';

void main() {
  IoTestContext ctx = IoTestContext();
  group('io', () {
    defineTests(ctx);
  });
}
