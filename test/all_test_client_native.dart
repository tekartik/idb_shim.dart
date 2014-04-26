library all_test_client_native;

import 'idb_test_browser.dart';
import 'package:unittest/unittest.dart';
import 'all_test_common.dart' as all_common;
import 'package:tekartik_idb/idb_client_native.dart';
import 'package:tekartik_idb/idb_client.dart';

testMain() {
  group('native', () {
    if (IdbNativeFactory.supported) {
      IdbFactory idbFactory = new IdbNativeFactory();
      all_common.testMain(idbFactory);
    } else {
      fail("idb native not supported");
    }
  });
}
main() {
  useHtmlConfiguration();
  testMain();
}
