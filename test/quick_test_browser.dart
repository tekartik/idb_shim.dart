library all_test_browser;

import 'simple_provider_test.dart' as simple_provider_test;
import 'transaction_test.dart' as transaction_test;
import 'exception_test.dart' as exception_test;
import 'index_test.dart' as index_test;
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_websql.dart';
import 'package:idb_shim/idb_client.dart';
import 'dart:async';
import 'idb_test_common.dart';

void testMain(TestContext ctx) {
  simple_provider_test.defineTests(ctx);
  index_test.defineTests(ctx);
  transaction_test.defineTests(ctx);
  exception_test.defineTests(ctx);
}

void main() {
  group('native', () {
    if (IdbNativeFactory.supported) {
      IdbFactory idbFactory = IdbNativeFactory();
      TestContext ctx = TestContext()..factory = idbFactory;
      testMain(ctx);
    } else {
      test("not supported", () {
        return Future.error("not supported");
      });
    }
  });
  group('websql', () {
    if (IdbWebSqlFactory.supported) {
      IdbWebSqlFactory idbFactory = IdbWebSqlFactory();
      TestContext ctx = TestContext()..factory = idbFactory;
      testMain(ctx);
    } else {
      test("not supported", () {
        return Future.error("not supported");
      });
    }
  });
  group('memory', () {
    testMain(idbMemoryContext);
  });
}
