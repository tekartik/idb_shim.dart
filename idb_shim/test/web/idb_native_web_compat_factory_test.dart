@TestOn('browser && !wasm')
library;

import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_native.dart' as native_web;
import 'package:idb_shim/idb_client_native_html.dart' as native_html;

import '../idb_test_common.dart';

void main() {
  group('idb_native_web_compat factory', () {
    test('idbFactoryFromIndexedDB', () async {
      var factory1 = native_html.idbFactoryNative;
      var factory2 = native_web.idbFactoryNative;

      var value = {
        'null': null,
        'bool': true,
        'int': 1,
        'list': [1, 2, 3],
        'map': {
          'sub': [
            1,
            2,
            {
              'sub2': [3, 4]
            }
          ],
        },
        'string': 'text',
        'dateTime': DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        'blob': Uint8List.fromList([1, 2, 3]),
      };
      Future<void> compatTest(IdbFactory factory1, IdbFactory factory2) async {
        var dbName = 'idbFactoryCompatTest';
        await factory1.deleteDatabase(dbName);
        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName);
        }

        var db = await factory1.open(dbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);
        var key = 1;
        expect(
            await db
                .transaction(testStoreName, idbModeReadOnly)
                .objectStore(testStoreName)
                .getObject(key),
            isNull);
        await db
            .transaction(testStoreName, idbModeReadWrite)
            .objectStore(testStoreName)
            .put(value, key);
        db.close();
        db = await factory2.open(dbName);

        expect(
            await db
                .transaction(testStoreName, idbModeReadOnly)
                .objectStore(testStoreName)
                .getObject(key),
            value);
        db.close();
      }

      await compatTest(factory2, factory1);
      await compatTest(factory1, factory2);
    });
  });
}
