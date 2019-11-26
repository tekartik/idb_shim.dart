@TestOn("browser")
library idb_browser_test;

import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_client.dart';

void main() {
  group('idb_browser', () {
    test('native', () {
      IdbFactory native = idbFactoryNative;
      if (native != null) {
        expect(native.runtimeType.toString(),
            "IdbFactoryNativeBrowserWrapperImpl");
        expect(native, idbFactoryBrowser);
      } else {
        fail("Native indexeddb not supported");
      }
    });

    test('memory', () {
      IdbFactory websql = idbFactoryMemory;
      expect(websql.runtimeType.toString(), "IdbFactorySembastImpl");
    });

    test('browser', () {
      expect(idbFactoryBrowser, isNot(isNull));
    });
  });
}
