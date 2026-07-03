import 'package:idb_shim/idb_sdb.dart';
import 'package:idb_shim/src/utils/env_utils.dart';
import 'package:test/test.dart';

//import '../sdb_test_common.dart';
//import 'package:sdb_shim/sdb_io.dart';

void main() {
  group('api', () {
    void expectBrowser([Object? e]) {
      if (e != null) {
        expect(e, isNot(const TypeMatcher<TestFailure>()));
      }
      // print('kIdbDartIsWeb: $kIdbDartIsWeb');
      expect(kIdbDartIsWeb, isTrue);
      //expect(sdbIsRunningAsJavascript, isTrue); // Not true for wasm
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
      sdbFactoryMemory;
      newIdbFactoryMemory;

      SdbDatabase? db;
      // ignore: dead_code
      db?.openDatabaseOptions;
      try {
        sdbFactoryIo;
        expectIo();
      } catch (e) {
        expectBrowser(e);
      }

      try {
        sdbFactoryWeb;
        expectBrowser();
      } catch (e) {
        expectIo(e);
      }
    });
  });
}
