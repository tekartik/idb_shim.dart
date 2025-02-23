import 'package:idb_shim/sdb.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  group('sdb_factory', () {
    test('init factory', () async {
      late SdbFactory factory;
      if (kSdbDartIsWeb) {
        // Web factory
        factory = sdbFactoryWeb;
      } else {
        // Io factory, prefer using sdbFactorySqflite though.
        factory = sdbFactoryIo;
      }
      var path = 'test.db';
      path = join('.dart_tool', 'idb_shim_test', 'sdb_factory', path);
      var db = await factory.openDatabase(path);
      await db.close();
    });
  });
}
