@TestOn('browser')
library idb_browser_test;

import 'dart:html';

import 'package:test/test.dart';
import 'package:idb_shim/idb_client_native.dart';

void main() {
  group('idb_native_factory', () {
    test('idbFactoryFromIndexedDB', () async {
      var factory1 = idbFactoryFromIndexedDB(window.indexedDB!);
      var factory2 = idbFactoryNative;
      var dbName = 'idbFactoryFromIndexedDB.db';
      var version = 1234;
      await factory1.deleteDatabase('idbFactoryFromIndexedDB.db');
      var db = await factory1.open(dbName,
          version: version, onUpgradeNeeded: (_) {});
      expect(db.version, version);
      db.close();
      // Open without version, should match
      db = await factory2.open(dbName);
      expect(db.version, version);
      db.close();
    });
  });
}
