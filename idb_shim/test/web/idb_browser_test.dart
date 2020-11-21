@TestOn('browser')
import 'package:idb_shim/idb_browser.dart';
import 'package:test/test.dart';

void main() {
  group('idb_browser', () {
    test('native', () {
      final native = idbFactoryNative;

      expect(
          native.runtimeType.toString(), 'IdbFactoryNativeBrowserWrapperImpl');
      expect(native, idbFactoryBrowser);
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
