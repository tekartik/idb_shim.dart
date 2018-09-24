@TestOn("browser")
library idb_shim.test_runner_client_native_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_native.dart';

import 'idb_browser_test_common.dart';
import 'idb_test_common.dart';
import 'test_runner.dart';

main() {
  group('native', () {
    if (IdbNativeFactory.supported) {
      IdbFactory idbFactory = IdbNativeFactory();
      TestContext ctx = TestContext()..factory = idbFactory;

      // ie and idb special test marker
      ctx.isIdbIe = isIe;
      ctx.isIdbSafari = isSafari;

      test('properties', () {
        expect(idbFactory.persistent, isTrue);
      });

      defineTests(ctx);
    } else {
      test("idb native not supported", null, skip: "idb native not supported");
    }
  });
}
