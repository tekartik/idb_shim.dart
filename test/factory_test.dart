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
    test('delete database', () {
      return idbFactory.deleteDatabase(testDbName);
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
        setUp(() {
          return idbFactory.getDatabaseNames().then((List<String> names) {
            List<Future> futures = new List();
            names.forEach((String name) {
              futures.add(idbFactory.deleteDatabase(name));
            });
            return Future.wait(futures);
          });
        });

        test('open find', () {
          return idbFactory.open("test").then((Database db) {
            db.close();
            return idbFactory.getDatabaseNames().then((List<String> names) {
              expect(names.length, 1);
              expect(names[0], "test");
            });
          });
        });

        test('open delete', () {
          return idbFactory.open("test").then((Database db) {
            db.close();
            return idbFactory.deleteDatabase("test").then((_) {
              return idbFactory.getDatabaseNames().then((List<String> names) {
                expect(names.length, 0);
              });
            });
          });
        });

        test('open 2 db', () {
          return idbFactory.open("test").then((Database db1) {
            db1.close();
            return idbFactory.open("test2").then((Database db2) {
              db2.close();
              return idbFactory.getDatabaseNames().then((List<String> names) {
                expect(names.length, 2);
                expect(names[0], "test");
                expect(names[1], "test2");
              });
            });
          });
        });

        test('open 2 db reopen 1', () {
          return idbFactory.open("test").then((Database db1) {
            db1.close();

            return idbFactory.open("test2").then((Database db2) {
              db2.close();

              return idbFactory.open("test").then((Database db1) {
                db1.close();

                return idbFactory.getDatabaseNames().then((List<String> names) {
                  //print(names.toString() + " - " + idbFactory.runtimeType.toString());
                  expect(names.length, 2);
                  expect(names[0], "test");
                  expect(names[1], "test2");
                });
              });
            });
          });
        });
      });
    } else {
      test('database names not supported', () {});
    }
  });
}
