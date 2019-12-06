@TestOn('browser')
library idb_browser_test;

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_client_websql.dart';

import '../../idb_test_common.dart';
import '../../multiplatform/simple_provider_test.dart' as simple_provider_test;

void main() {
  group('compat', () {
    test('api', () {
      // ignore: deprecated_member_use_from_same_package
      idbNativeFactory;
      // ignore: unnecessary_statements, deprecated_member_use_from_same_package
      IdbNativeFactory;
      // ignore: deprecated_member_use_from_same_package
      IdbNativeFactory();
    });
    group('native', () {
      test('native', () {
        expect(
            // ignore: deprecated_member_use_from_same_package
            IdbNativeFactory.supported,
            // ignore: deprecated_member_use_from_same_package
            IdbFactoryNative.supported);
        expect(

            // ignore: deprecated_member_use_from_same_package
            IdbFactoryNative.supported,
            idbFactoryNative != null);
      });
      // ignore: deprecated_member_use_from_same_package
      if (IdbFactoryNative.supported) {
        IdbFactory idbFactory =
            // ignore: deprecated_member_use_from_same_package
            IdbNativeFactory();
        final ctx = TestContext()..factory = idbFactory;
        simpleTest(ctx);
      }
    });
    group('persistent', () {
      test('factory', () {
        expect(
            // ignore: deprecated_member_use_from_same_package
            idbPersistentFactory,
            idbFactoryNative);
      });
    });

    group('browser', () {
      test('factory', () {
        expect(
            // ignore: deprecated_member_use_from_same_package
            idbBrowserFactory,
            idbFactoryNative);
        expect(
            // ignore: deprecated_member_use_from_same_package
            idbBrowserFactory,
            idbFactoryBrowser);

        // ignore: deprecated_member_use_from_same_package
        expect(idbBrowserFactory, isNot(isNull));
      });
    });

    group('websql', () {
      test('factory', () {
        // ignore: deprecated_member_use_from_same_package
        expect(idbFactoryWebSql, isNull);
        // ignore: deprecated_member_use_from_same_package
        expect(idbWebSqlFactory, isNull);
      });
    });
  });
}

void simpleTest(TestContext ctx) {
  simple_provider_test.defineTests(ctx);
}
