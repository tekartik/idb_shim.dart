@TestOn("browser")
library idb_shim.test_runner_client_native_test;

import 'idb_test_common.dart';
import 'test_runner.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client.dart';
import 'idb_browser_test_common.dart';

main() {
  group('native', () {
    if (IdbNativeFactory.supported) {
      IdbFactory idbFactory = new IdbNativeFactory();
      TestContext ctx = new TestContext()..factory = idbFactory;

      // ie and idb special test marker
      ctx.isIdbIe = isIe;

      test('properties', () {
        expect(idbFactory.persistent, isTrue);
      });

      defineTests(ctx);
    } else {
      test("idb native not supported", null, skip: "idb native not supported");
    }
  });
}
