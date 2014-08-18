library all_test_browser;

import 'idb_test_browser.dart';
import 'all_test_client_native.dart' as native;
import 'all_test_client_websql.dart' as websql;
import 'all_test_client_memory.dart' as memory;
import 'idb_browser_test.dart' as browser;
import 'common_value_test.dart' as common_value_test;
import 'idb_test_common_test.dart' as idb_test_common_test;

main() {
  useHtmlConfiguration();
  native.testMain();
  websql.testMain();
  memory.testMain();
  browser.testMain();
  common_value_test.main();
  idb_test_common_test.main();
}
