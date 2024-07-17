import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:test/test.dart';

void main() {
  group('import', () {
    test('web', () {
      try {
        idbFactoryNative;
        if (!kIdbDartIsWeb) {
          fail('should fail');
        }
      } on UnimplementedError catch (_) {}
    });

    test('io', () {
      try {
        idbFactorySembastIo;
        if (kIdbDartIsWeb) {
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
