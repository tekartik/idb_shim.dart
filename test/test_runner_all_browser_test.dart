@TestOn("browser")
library all_test_browser;

import 'test_runner_client_native_test.dart' as native;
import 'test_runner_client_websql_test.dart' as websql;
import 'idb_browser_test.dart' as browser;
import 'common_value_test.dart' as common_value_test;
import 'idb_test_common_test.dart' as idb_test_common_test;
import 'test_runner.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:test/test.dart';

main() {
  native.main();
  websql.testMain();
  browser.testMain();
  common_value_test.main();
  idb_test_common_test.main();
  defineTests(idbSembastMemoryFactory);
}
