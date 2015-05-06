library all_test_browser;

import 'simple_provider_test.dart' as simple_provider_test;
import 'transaction_test.dart' as transaction_test;
import 'index_test.dart' as index_test;
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_websql.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client.dart';
import 'dart:async';
import 'package:test/test.dart';

testMain(IdbFactory idbFactory) {
  simple_provider_test.defineTests(idbFactory);
  index_test.defineTests(idbFactory);
  transaction_test.defineTests(idbFactory);
}

main() {
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
    testMain(idbMemoryFactory);
  });
}
