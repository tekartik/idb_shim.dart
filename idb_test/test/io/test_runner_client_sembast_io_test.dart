@TestOn('vm')
library idb_shim.test_runner_sembast_io;

import 'package:test/test.dart';

import '../multiplatform/test_runner_client_sembast_fs_test.dart';
import 'idb_io_test_common.dart';

void main() {
  final ctx = IoTestContext();
  group('io', () {
    defineTests(ctx);
  });
}
