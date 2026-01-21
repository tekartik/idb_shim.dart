import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_shim/idb_io.dart';
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
        expect(factory.idbFactory, idbFactoryWeb);
        expect(factory.idbFactory.underlyingSembastFactoryOrNull, isNull);
      } else {
        // Io factory, prefer using sdbFactorySqflite though.
        factory = sdbFactoryIo;
        expect(factory.idbFactory, idbFactorySembastIo);
        var idbFactorySembast = factory.idbFactory as IdbFactorySembast;
        expect(
          factory.idbFactory.underlyingSembastFactoryOrNull,
          idbFactorySembast.sembastFactory,
        );
      }
      var path = 'test.db';
      path = join('.dart_tool', 'idb_shim_test', 'sdb_factory', path);
      var db = await factory.openDatabase(path);
      await db.close();
    });
  });
}
