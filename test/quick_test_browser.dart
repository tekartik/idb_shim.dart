library all_test_browser;

import 'package:tekartik_test/test_config_browser.dart';
import 'simple_provider_test.dart' as simple_provider_test;
import 'transaction_test.dart' as transaction_test;
import 'index_test.dart' as index_test;
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_websql.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client.dart';
import 'dart:async';

testMain(IdbFactory idbFactory) {
  simple_provider_test.testMain(idbFactory);
  index_test.defineTests(idbFactory);
  transaction_test.defineTests(idbFactory);
}

main() {
  useHtmlConfiguration();
  group('native', () {
    if (IdbNativeFactory.supported) {
      IdbFactory idbFactory = new IdbNativeFactory();
      testMain(idbFactory);
    } else {
      test("not supported", () {
        return new Future.error("not supported");
      });
    }
  });
  group('websql', () {
    if (IdbWebSqlFactory.supported) {
      IdbWebSqlFactory idbFactory = new IdbWebSqlFactory();
      testMain(idbFactory);
    } else {
      test("not supported", () {
        return new Future.error("not supported");
      });
    }
  });
  group('memory', () {
    IdbFactory idbFactory = new IdbMemoryFactory();
    testMain(idbFactory);
  });
}
