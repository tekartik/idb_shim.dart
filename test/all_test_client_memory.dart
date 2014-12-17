library all_test_client_memory;

import 'package:tekartik_test/test_config_browser.dart';
import 'test_runner.dart' as test_runner;
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
    test_runner.defineTests(idbFactory);
  });
}
main() {
  useHtmlConfiguration();
  testMain();
}
