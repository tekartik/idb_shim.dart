@TestOn("browser")
library idb_shim.test_runner_client_websql;

import 'idb_test_common.dart';
import 'test_runner.dart' as test_runner;
import 'websql_wrapper_test.dart' as websql_wrapper_test;
import 'websql_client_test.dart' as websql_client_test;
import 'package:idb_shim/idb_client_websql.dart';
import 'package:idb_shim/src/websql/websql_wrapper.dart' as wrapper;
import 'dart:web_sql';
import 'dart:html';
import 'dart:async';

webSqlTest(IdbWebSqlFactory idbFactory) {
  test('properties', () {
    expect(idbFactory.persistent, isTrue);
  });

  group('native', () {
    test('openDatabase', () {
      Completer completer = new Completer();
      SqlDatabase db = window.openDatabase(
          "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
      db.transaction((txn) {
        completer.complete();
      });
      return completer.future;
    });

    test('transaction', () {
      Completer completer = new Completer();
      SqlDatabase db = window.openDatabase(
          "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
      db.transaction((txn) {
        txn.executeSql("DROP TABLE IF EXISTS test", [], (txn, rs) {
          completer.complete();
        });
      });
      return completer.future;
    });

    test('transaction in future', () {
      Completer completer = new Completer();
      Completer syncCompleter = new Completer.sync();
      SqlDatabase db = window.openDatabase(
          "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
      db.transaction((txn) {
        txn.executeSql("DROP TABLE IF EXISTS test", []);
        syncCompleter.complete(txn);
      });
      return syncCompleter.future.then((txn) {
        try {
          txn.executeSql("CREATE TABLE test (name TEXT)", [], (txn, rs) {
            completer.complete();
          });
        } catch (e) {
          // in js this will fail
        }
      });
    });
  });
}

main() {
  group('websql', () {
    //wrapper.SqlDatabase.debug = true;
    if (IdbWebSqlFactory.supported) {
      //idb_wql.SqlDatabase.debug = true;
      IdbWebSqlFactory idbFactory = new IdbWebSqlFactory();
      TestContext ctx = new TestContext()..factory = idbFactory;
      test_runner.defineTests_(ctx);
      websql_wrapper_test.main();
      websql_client_test.main();
      webSqlTest(idbFactory);
    } else {
      /**
       * to display something
       */
      test("not supported", () {});
    }
  });
}
