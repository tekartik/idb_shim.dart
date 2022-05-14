import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/idb_shim.dart';

import '../idb_test_common.dart';
//import 'package:idb_shim/idb_io.dart';

void main() {
  group('api', () {
    void expectBrowser([Object? e]) {
      if (e != null) {
        expect(e, isNot(const TypeMatcher<TestFailure>()));
      }
      expect(idbIsRunningAsJavascript, isTrue);
    }

    void expectIo([Object? e]) {
      if (e != null) {
        expect(e, isNot(const TypeMatcher<TestFailure>()));
      }
      expect(idbIsRunningAsJavascript, isFalse);
    }

    test('api', () {
      // ignore_for_file: unnecessary_statements
      idbFactoryMemory;
      idbFactoryMemoryFs;
      newIdbFactoryMemory;

      try {
        idbFactorySembastIo;
        expectIo();
      } catch (e) {
        expectBrowser(e);
      }

      try {
        idbFactoryNative;
        expectBrowser();
      } catch (e) {
        expectIo(e);
      }
    });
  });
}
