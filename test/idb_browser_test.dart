@TestOn("browser")
library idb_browser_test;

import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_client.dart';

main() {
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
    }, skip: idbWebSqlFactory == null ? "WebSql not supported" : false);

    test('memory', () {
      IdbFactory websql = idbMemoryFactory;
      expect(websql.runtimeType.toString(), "IdbSembastFactory");
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
