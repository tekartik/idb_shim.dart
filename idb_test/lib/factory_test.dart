library factory_test;

import 'dart:async';
import 'dart:typed_data';

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;
  group('factory', () {
    String _dbName;

    // prepare for test
    Future _setupDeleteDb() async {
      _dbName = ctx.dbName;
      await idbFactory.deleteDatabase(_dbName);
    }

    test('delete database', () async {
      await _setupDeleteDb();
      await idbFactory.deleteDatabase(_dbName);
    });

    test('cmp', () {
      expect(idbFactory.cmp(1, 2), -1);
      expect(idbFactory.cmp(1, 1), 0);
      expect(idbFactory.cmp(2, 1), 1);
      expect(idbFactory.cmp('a', 'b'), -1);
      expect(idbFactory.cmp('a', 'a'), 0);
      expect(idbFactory.cmp('b', 'a'), 1);
      expect(idbFactory.cmp(3.14, 3.45), -1);
      expect(idbFactory.cmp(3.14, 3.14), 0);
      expect(idbFactory.cmp(3.64, 3.45), 1);

      expect(
          idbFactory.cmp(
              Uint8List.fromList([1, 2]), Uint8List.fromList([1, 3])),
          -1);
      expect(
          idbFactory.cmp(
              Uint8List.fromList([1, 3]), Uint8List.fromList([1, 2])),
          1);

      var hasFailed = false;
      try {
        idbFactory.cmp(null, 1);
      } catch (_) {
        // DataError: Failed to execute 'cmp' on 'IDBFactory': The parameter is not a valid key
        hasFailed = true;
      }
      expect(hasFailed, isTrue);

      hasFailed = false;
      try {
        idbFactory.cmp(1, null);
      } catch (_) {
        // DataError: Failed to execute 'cmp' on 'IDBFactory': The parameter is not a valid key
        hasFailed = true;
      }
      expect(hasFailed, isTrue);

      // Fail to compare bool
      hasFailed = false;
      try {
        idbFactory.cmp(false, true);
      } catch (_) {
        // DataError: Failed to execute 'cmp' on 'IDBFactory': The parameter is not a valid key
        hasFailed = true;
      }
      expect(hasFailed, isTrue);

      // Fail to compare DateTime
      hasFailed = false;
      try {
        idbFactory.cmp(DateTime.fromMillisecondsSinceEpoch(1),
            DateTime.fromMillisecondsSinceEpoch(2));
      } catch (_) {
        // DataError: Failed to execute 'cmp' on 'IDBFactory': The parameter is not a valid key
        hasFailed = true;
      }
      expect(hasFailed, isTrue);
    });

    test('cmp array', () {
      expect(idbFactory.cmp([1, 2], [1, 3]), -1);
      expect(idbFactory.cmp([1, 2], [1, 2]), 0);
      expect(idbFactory.cmp([1, 2], [1, 1]), 1);
    });

    /*
    test('delete null failing', () {
      return idbFactory.deleteDatabase(null).then((_) {
        fail('should fail');
      }, onError: (e) {
        //print(e);
      });
    }, testOn: '!js');

    test('delete null not failing', () {
      return idbFactory.deleteDatabase(null).then((_) {});
    }, testOn: 'js');
    */

    if (idbFactory.supportsDatabaseNames) {
      test('supportsDatabaseNames', () {
        expect(idbFactory.supportsDatabaseNames, true);
      });
      test('database names', () {
        return idbFactory.getDatabaseNames().then((List<String> names) {
          expect(names, isNotNull);
        });
      });

      group('databases', () {
        /*
        setUp(() {
          // delete all
          return idbFactory.getDatabaseNames().then((List<String> names) {
            List<Future> futures = new List();
            names.forEach((String name) {
              futures.add(idbFactory.deleteDatabase(name));
            });
            return Future.wait(futures);
          });
        });
        */

        test('open find', () async {
          await _setupDeleteDb();
          final db = await idbFactory.open(_dbName);
          db.close();

          final names = await idbFactory.getDatabaseNames();
          expect(names, contains(_dbName));
        });

        test('open delete', () async {
          await _setupDeleteDb();
          final db = await idbFactory.open(_dbName);
          db.close();

          var names = await idbFactory.getDatabaseNames();
          expect(names, contains(_dbName));
          await idbFactory.deleteDatabase(_dbName);
          names = await idbFactory.getDatabaseNames();
          expect(names, isNot(contains(_dbName)));
        });

        test('open 2 db', () async {
          final dbName1 = '${ctx.dbName}1';
          final dbName2 = '${ctx.dbName}2';
          await idbFactory.deleteDatabase(dbName1);
          await idbFactory.deleteDatabase(dbName2);
          (await idbFactory.open(dbName1)).close();
          (await idbFactory.open(dbName2)).close();

          final names = await idbFactory.getDatabaseNames();
          expect(names, contains(dbName1));
          expect(names, contains(dbName2));
        });

        test('open 2 db reopen 1', () async {
          final dbName1 = '${ctx.dbName}1';
          final dbName2 = '${ctx.dbName}2';
          await idbFactory.deleteDatabase(dbName1);
          await idbFactory.deleteDatabase(dbName2);
          (await idbFactory.open(dbName1)).close();
          (await idbFactory.open(dbName2)).close();

          var names = await idbFactory.getDatabaseNames();
          final length = names.length;
          expect(names, contains(dbName1));
          expect(names, contains(dbName2));

          names = await idbFactory.getDatabaseNames();
          expect(names.length, length);
        });
      });
    } else {
      test('database names not supported', () {});
    }
  });
}
