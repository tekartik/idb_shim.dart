import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/src/utils/env_utils.dart'
    show idbIsRunningAsJavascript;
import 'package:test/test.dart';

import '../idb_test_common.dart';
//import 'package:idb_shim/idb_io.dart';

void main() {
  group('api', () {
    void _expectBrowser([Object? e]) {
      if (e != null) {
        expect(e, isNot(const TypeMatcher<TestFailure>()));
      }
      expect(idbIsRunningAsJavascript, isTrue);
    }

    void _expectIo([Object? e]) {
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
        _expectIo();
      } catch (e) {
        _expectBrowser(e);
      }

      try {
        idbFactoryNative;
        _expectBrowser();
      } catch (e) {
        _expectIo(e);
      }
    });
  });
}
