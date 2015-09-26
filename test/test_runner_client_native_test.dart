@TestOn("browser")
library idb_shim.test_runner_client_native_test;

import 'package:test/test.dart';
import 'test_runner.dart' as test_runner;
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client.dart';

main() {
  group('native', () {
    if (IdbNativeFactory.supported) {
      IdbFactory idbFactory = new IdbNativeFactory();

      test('properties', () {
        expect(idbFactory.persistent, isTrue);
      });

      test_runner.defineTests(idbFactory);
    } else {
      fail("idb native not supported");
    }
  });
}
