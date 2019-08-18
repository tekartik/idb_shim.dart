@TestOn("browser")
library idb_shim.test_runner_all_browser_test;

import 'package:dev_test/test.dart';

import '../multiplatform/common_value_test.dart' as common_value_test;
import '../multiplatform/idb_test_common_test.dart' as idb_test_common_test;
import '../multiplatform/test_runner_client_sembast_fs_test.dart' as sembast_fs;
import '../multiplatform/test_runner_client_sembast_memory_test.dart'
    as sembast_memory;
import 'idb_browser_test.dart' as browser;
import 'test_runner_client_native_test.dart' as native;

void main() {
  native.main();
  sembast_memory.main();
  sembast_fs.main();

  browser.main();
  common_value_test.main();
  idb_test_common_test.main();
}
