@TestOn("vm")

library all_test_console;

import 'package:test/test.dart';
import 'test_runner.dart';
import 'common_value_test.dart' as common_value_test;
import 'common_meta_test.dart' as common_meta_test;
import 'idb_test_common_test.dart' as idb_test_common_test;
import 'package:idb_shim/idb_io.dart';

void main() {

  defineTests(idbSembastMemoryFactory);
  defineTests(getIdbSembastIoFactory("tmp"));
  common_value_test.main();
  common_meta_test.main();
  idb_test_common_test.main();
}
