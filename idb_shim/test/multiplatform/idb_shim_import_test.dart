import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:test/test.dart';

import '../idb_test_common.dart' show idbIsRunningAsJavascript;

void main() {
  group('import', () {
    test('web', () {
      try {
        idbFactoryNative;
        if (!idbIsRunningAsJavascript) {
          fail('should fail');
        }
      } on UnimplementedError catch (_) {}
    });

    test('io', () {
      try {
        idbFactorySembastIo;
        if (idbIsRunningAsJavascript) {
          fail('should fail');
        }
      } on UnimplementedError catch (_) {}
    });

    test('memory', () {
      idbFactoryMemory;
      idbFactoryMemoryFs;
    });
  });
}
