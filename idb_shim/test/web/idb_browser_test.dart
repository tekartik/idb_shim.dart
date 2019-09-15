@TestOn("browser")
library idb_browser_test;

import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_client.dart';

void main() {
  group('idb_browser', () {
    test('native', () {
      IdbFactory native = idbNativeFactory;
      if (native != null) {
        expect(native.runtimeType.toString(), "IdbFactoryNativeImpl");
        expect(native, idbPersistentFactory);
        expect(native, idbBrowserFactory);
      } else {
        fail("Native indexeddb not supported");
      }
    });

    test('websql', () {
      // ignore: deprecated_member_use_from_same_package
      IdbFactory websql = idbFactoryWebSql;
      if (websql != null) {
        expect(websql.runtimeType.toString(), "IdbWebSqlFactory");
        expect(idbPersistentFactory, isNot(isNull));
      } else {
        fail("WebSql not supported");
      }
      // ignore: deprecated_member_use_from_same_package
    }, skip: idbFactoryWebSql == null ? "WebSql not supported" : false);

    test('memory', () {
      IdbFactory websql = idbMemoryFactory;
      expect(websql.runtimeType.toString(), "IdbFactorySembastImpl");
    });

    test('persistent', () {
      if (idbPersistentFactory == null) {
        expect(idbNativeFactory, isNull);
        // ignore: deprecated_member_use_from_same_package
        expect(idbFactoryWebSql, isNull);
      }
    });

    test('browser', () {
      expect(idbBrowserFactory, isNot(isNull));
    });
  });
}
