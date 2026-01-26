@TestOn('vm')
library;

import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/idb_jdb.dart';
import 'package:sembast/sembast.dart';

import 'package:test/test.dart';

var testPath = '.dart_tool/idb_shim/test/databases';

Future main() async {
  var jdbFactory = JdbFactoryIdb(getIdbFactorySembastIo(testPath));
  var factory = DatabaseFactoryJdb(jdbFactory);

  group('idb_io', () {
    test('open', () async {
      var store = StoreRef<String, String>.main();
      var record = store.record('key');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test');
      expect(await record.get(db), isNull);
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();

      db = await factory.openDatabase('test');
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();
    });
  });
}
