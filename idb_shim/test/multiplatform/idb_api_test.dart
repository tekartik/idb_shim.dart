import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/src/utils/env_utils.dart'
    show idbIsRunningAsJavascript, kIdbDartIsWeb;
import 'package:idb_shim/utils/idb_utils.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';
//import 'package:idb_shim/idb_io.dart';

void main() {
  group('api', () {
    void expectBrowser([Object? e]) {
      if (e != null) {
        expect(e, isNot(const TypeMatcher<TestFailure>()));
      }
      // print('kIdbDartIsWeb: $kIdbDartIsWeb');
      expect(kIdbDartIsWeb, isTrue);
      //expect(idbIsRunningAsJavascript, isTrue); // Not true for wasm
    }

    void expectIo([Object? e]) {
      if (e != null) {
        expect(e, isNot(const TypeMatcher<TestFailure>()));
      }
      expect(kIdbDartIsWeb, isFalse);
      expect(idbIsRunningAsJavascript, isFalse); // Not true for wasm
    }

    test('api', () {
      // ignore_for_file: unnecessary_statements
      idbFactoryMemory;
      idbFactoryMemoryFs;
      newIdbFactoryMemory;
      cursorToList;
      cursorToKeyList;
      cursorToPrimaryKeyList;
      keyCursorToList;

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
