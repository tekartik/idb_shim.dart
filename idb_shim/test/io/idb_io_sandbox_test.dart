@TestOn('vm')
library;

import 'dart:io';

import 'package:idb_shim/idb_io.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

var testPath = join('.dart_tool', 'idb_shim', 'test', 'sandbox_io');

Future main() async {
  group('idb_io_sandbox', () {
    test('open/delete', () async {
      var idbFactory = idbFactorySembastIo;
      var sandboxed = idbFactory.sandbox(path: testPath);
      var dbName = 'test.db';
      await sandboxed.deleteDatabase(dbName);
      var db = await sandboxed.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (event) {
          event.database.createObjectStore('store');
        },
      );
      expect(db.objectStoreNames, ['store']);
      db.close();

      // The database file is below the sandbox path.
      expect(File(join(testPath, dbName)).existsSync(), isTrue);

      // And visible in the delegate factory.
      db = await idbFactory.open(join(testPath, dbName));
      expect(db.version, 1);
      expect(db.objectStoreNames, ['store']);
      db.close();

      await sandboxed.deleteDatabase(dbName);
      expect(File(join(testPath, dbName)).existsSync(), isFalse);
    });

    test('escape throws', () async {
      var sandboxed = idbFactorySembastIo.sandbox(path: testPath);
      expect(() => sandboxed.open(join('..', 'other.db')), throwsArgumentError);
    });
  });
}
