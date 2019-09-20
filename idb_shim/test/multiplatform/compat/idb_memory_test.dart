@TestOn("browser")
library idb_browser_test;

import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_browser.dart';

import '../../idb_test_common.dart';
import '../../multiplatform/simple_provider_test.dart' as simple_provider_test;

void main() {
  group('compat', () {
    test('api', () {
      // ignore: deprecated_member_use_from_same_package
      idbMemoryFsFactory;
      // ignore: deprecated_member_use_from_same_package
      idbMemoryFactory;
    });
    group('memory', () {
      simpleTest(TestContext()
        ..factory =
            // ignore: deprecated_member_use_from_same_package
            idbMemoryFsFactory);
      simpleTest(TestContext()
        ..factory =
            // ignore: deprecated_member_use_from_same_package
            idbMemoryFactory);
    });
  });
}

void simpleTest(TestContext ctx) {
  simple_provider_test.defineTests(ctx);
}
