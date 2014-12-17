library all_test_client_native;

import 'package:tekartik_test/test_config_browser.dart';
import 'test_runner.dart' as test_runner;
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_client_sembast.dart';

idbMemoryTest(IdbSembastFactory idbFactory) {
  test('properties', () {
    // it is in memory
    expect(idbFactory.persistent, isFalse);
  });
}
  
testMain() {
  group('sembast', () {
    IdbFactory idbFactory = idbSembastMemoryFactory;
    idbMemoryTest(idbFactory);
    test_runner.defineTests(idbFactory);
  });
}
main() {
  useHtmlConfiguration();
  testMain();
}