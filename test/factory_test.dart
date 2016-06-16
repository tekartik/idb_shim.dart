library factory_test;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';
import 'dart:async';

// so that this can be run directly
main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;
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

    /*
    test('delete null failing', () {
      return idbFactory.deleteDatabase(null).then((_) {
        fail("should fail");
      }, onError: (e) {
        //print(e);
      });
    }, testOn: "!js");

    test('delete null not failing', () {
      return idbFactory.deleteDatabase(null).then((_) {});
    }, testOn: "js");
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
          Database db = await idbFactory.open(_dbName);
          db.close();

          List<String> names = await idbFactory.getDatabaseNames();
          expect(names, contains(_dbName));
        });

        test('open delete', () async {
          await _setupDeleteDb();
          Database db = await idbFactory.open(_dbName);
          db.close();

          List<String> names = await idbFactory.getDatabaseNames();
          expect(names, contains(_dbName));
          await idbFactory.deleteDatabase(_dbName);
          names = await idbFactory.getDatabaseNames();
          expect(names, isNot(contains(_dbName)));
        });

        test('open 2 db', () async {
          String dbName1 = "${ctx.dbName}1";
          String dbName2 = "${ctx.dbName}2";
          await idbFactory.deleteDatabase(dbName1);
          await idbFactory.deleteDatabase(dbName2);
          (await idbFactory.open(dbName1)).close();
          (await idbFactory.open(dbName2)).close();

          List<String> names = await idbFactory.getDatabaseNames();
          expect(names, contains(dbName1));
          expect(names, contains(dbName2));
        });

        test('open 2 db reopen 1', () async {
          String dbName1 = "${ctx.dbName}1";
          String dbName2 = "${ctx.dbName}2";
          await idbFactory.deleteDatabase(dbName1);
          await idbFactory.deleteDatabase(dbName2);
          (await idbFactory.open(dbName1)).close();
          (await idbFactory.open(dbName2)).close();

          List<String> names = await idbFactory.getDatabaseNames();
          int length = names.length;
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
