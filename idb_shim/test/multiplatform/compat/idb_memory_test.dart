@TestOn("browser")
library idb_browser_test;

// ignore_for_file: deprecated_member_use_from_same_package, deprecated_member_use

import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_browser.dart';

import '../../idb_test_common.dart';
import '../../multiplatform/simple_provider_test.dart' as simple_provider_test;

void main() {
  group('compat', () {
    test('api', () {
      idbMemoryFsFactory;
      idbMemoryFactory;
    });
    group('memory', () {
      simpleTest(TestContext()..factory = idbMemoryFsFactory);
      simpleTest(TestContext()..factory = idbMemoryFactory);
    });
  });
}

void simpleTest(TestContext ctx) {
  simple_provider_test.defineTests(ctx);
}
