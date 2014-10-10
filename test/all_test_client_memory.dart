library all_test_client_memory;

import 'idb_test_browser.dart';
import 'package:unittest/unittest.dart';
import 'all_test_common.dart' as all_common;
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client.dart';

idbMemoryTest(IdbMemoryFactory idbFactory) {

  test('properties', () {
    expect(idbFactory.persistent, isFalse);
  });
}
  
testMain() {
  group('memory', () {
    IdbFactory idbFactory = new IdbMemoryFactory();
    idbMemoryTest(idbFactory);
    all_common.testMain(idbFactory);
  });
}
main() {
  useHtmlConfiguration();
  testMain();
}
