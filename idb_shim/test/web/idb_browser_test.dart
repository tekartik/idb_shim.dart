@TestOn('browser')
library idb_browser_test;

import 'package:dev_test/test.dart';
import 'package:idb_shim/idb_browser.dart';

void main() {
  group('idb_browser', () {
    test('native', () {
      final native = idbFactoryNative;
      if (native != null) {
        expect(native.runtimeType.toString(),
            'IdbFactoryNativeBrowserWrapperImpl');
        expect(native, idbFactoryBrowser);
      } else {
        fail('Native indexeddb not supported');
      }
    });

    test('memory', () {
      final websql = idbFactoryMemory;
      expect(websql.runtimeType.toString(), 'IdbFactorySembastImpl');
    });

    test('browser', () {
      expect(idbFactoryBrowser, isNot(isNull));
    });
  });
}
