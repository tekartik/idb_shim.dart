@TestOn('browser')
library;

import 'package:idb_shim/idb_client_native.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';

void main() {
  group('idb_native_web_factory', () {
    test('idbFactoryFromIndexedDB', () async {
      var factory1 = idbFactoryFromIndexedDB(window.indexedDB);
      var factory2 = idbFactoryNative;
      var dbName = 'idbFactoryFromIndexedDB.db';
      var version = 1234;
      await factory1.deleteDatabase(dbName);
      var db = await factory1.open(dbName,
          version: version, onUpgradeNeeded: (_) {});
      expect(db.version, version);
      db.close();
      // Open without version, should match
      db = await factory2.open(dbName);
      expect(db.version, version);
      db.close();
    }, skip: !idbFactoryNativeSupported);
    test('idbFactoryWeb', () async {
      var factory = idbFactoryWeb;
      var dbName = 'idb_factory_web.db';
      var version = 1234;
      await factory.deleteDatabase(dbName);
      var db =
          await factory.open(dbName, version: version, onUpgradeNeeded: (_) {});
      expect(db.version, version);
      db.close();
      // Open without version, should match
      db = await factory.open(dbName);
      expect(db.version, version);
      db.close();
    }, skip: !idbFactoryWebSupported);
  });
}
