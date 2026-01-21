@TestOn('browser')
library;

import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:test/test.dart';

void main() {
  group('idb_browser', () {
    test('native', () {
      final native = idbFactoryNative;

      expect(
        native.runtimeType.toString(),
        'IdbFactoryNativeBrowserWrapperImpl',
      );
      expect(native, idbFactoryBrowser);
      expect(native.underlyingSembastFactoryOrNull, isNull);
    });

    test('memory', () {
      final memory = idbFactoryMemory;
      expect(memory.runtimeType.toString(), 'IdbFactorySembastImpl');
    });

    test('browser', () {
      expect(idbFactoryBrowser, isNot(isNull));
    });
  });
}
