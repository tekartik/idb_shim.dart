library all_test_client_websql;

import 'idb_test_browser.dart';
import 'package:unittest/unittest.dart';
import 'all_test_common.dart' as all_common;
import 'websql_wrapper_test.dart' as websql_wrapper_test;
import 'websql_client_test.dart' as websql_client_test;
import 'package:idb_shim/idb_client_websql.dart';
import 'dart:web_sql';
import 'dart:html';
import 'dart:async';

webSqlTest(IdbWebSqlFactory idbFactory) {

  group('native', () {

    test('openDatabase', () {
      Completer completer = new Completer();
      SqlDatabase db = window.openDatabase("com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
      db.transaction((txn) {
        completer.complete();
      });
      return completer.future;

    });

    test('transaction', () {
      Completer completer = new Completer();
      SqlDatabase db = window.openDatabase("com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
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
      SqlDatabase db = window.openDatabase("com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
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

testMain() {
  group('websql', () {
    if (IdbWebSqlFactory.supported) {
      IdbWebSqlFactory idbFactory = new IdbWebSqlFactory();
      all_common.testMain(idbFactory);
      websql_wrapper_test.testMain();
      websql_client_test.testMain();
      webSqlTest(idbFactory);
    } else {
      /**
       * to display something
       */
      test("not supported", () {

      });
    }
  });
}
main() {
  useHtmlConfiguration();
  testMain();
}
