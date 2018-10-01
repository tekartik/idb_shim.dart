@TestOn("browser")
library idb_shim.test_runner_all_browser_test;

import 'test_runner_client_native_test.dart' as native;
import 'test_runner_client_sembast_memory_test.dart' as sembast_memory;
import 'test_runner_client_sembast_fs_test.dart' as sembast_fs;
import 'idb_browser_test.dart' as browser;
import 'common_value_test.dart' as common_value_test;
import 'idb_test_common_test.dart' as idb_test_common_test;
import 'package:dev_test/test.dart';

void main() {
  native.main();
  sembast_memory.main();
  sembast_fs.main();

  browser.main();
  common_value_test.main();
  idb_test_common_test.main();
}
