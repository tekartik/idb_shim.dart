@TestOn("vm")
library all_test_console;

import 'package:dev_test/test.dart';

import '../multiplatform/common_meta_test.dart' as common_meta_test;
import '../multiplatform/common_value_test.dart' as common_value_test;
import '../multiplatform/idb_test_common_test.dart' as idb_test_common_test;
import '../multiplatform/test_runner_client_sembast_memory_test.dart'
    as sembast_memory;
import '../test_runner_client_sembast_io_test.dart' as sembast_io;

void main() {
  sembast_memory.main();
  sembast_io.main();

  common_value_test.main();
  common_meta_test.main();
  idb_test_common_test.main();
}
