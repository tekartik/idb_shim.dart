library idb_browser_test;

import 'package:tekartik_test/test_config_browser.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_client.dart';

testMain() {
  group('idb_browser', () {
    test('native', () {
      IdbFactory native = idbNativeFactory;
      if (native != null) {
        expect(native.runtimeType.toString(), "IdbNativeFactory");
        expect(native, idbPersistentFactory);
        expect(native, idbBrowserFactory);
      } else {
        fail("Native indexeddb not supported");
      }
    });

    test('websql', () {
      IdbFactory websql = idbWebSqlFactory;
      if (websql != null) {
        expect(websql.runtimeType.toString(), "IdbWebSqlFactory");
        expect(idbPersistentFactory, isNot(isNull));
      } else {
        fail("WebSql not supported");
      }
    });

    test('memory', () {
      IdbFactory websql = idbMemoryFactory;
      expect(websql.runtimeType.toString(), "IdbMemoryFactory");

    });

    test('persistent', () {
      if (idbPersistentFactory == null) {
        expect(idbNativeFactory, isNull);
        expect(idbWebSqlFactory, isNull);
      }
    });

    test('browser', () {
      expect(idbBrowserFactory, isNot(isNull));
    });
  });
}

main() {
  useHtmlConfiguration();
  testMain();
}
