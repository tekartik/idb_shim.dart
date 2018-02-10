@TestOn("browser")
library websql_raw_test;

import 'dart:async';
import 'dart:html';
import 'dart:web_sql';

import 'package:dev_test/test.dart';
import 'package:idb_shim/src/websql/websql_utils.dart';

main() {
  if (SqlDatabase.supported) {
    group('websql_raw', () {
      test('bug_dart2.0.0-dev', () async {
        SqlDatabase db = window.openDatabase(
            "websql_raw_test_2", "1", "WebSql raw test 2", 50 * 1000);
        var completer = new Completer();
        SqlResultSet rs_;
        db.transaction((txn) {
          txn.executeSql("DROP TABLE IF EXISTS test");
          txn.executeSql("CREATE TABLE test (value TEXT)");
          txn.executeSql("INSERT INTO test (value) VALUES (?)", ["first"]);
          txn.executeSql("SELECT * FROM test", [], (_, SqlResultSet rs) {
            rs_ = rs;
          });
        }, (e) {
          completer.completeError(e.message);
        }, () {
          completer.complete(null);
        });

        await completer.future;

        // We should get a single row {"value": "first"}
        var row = getRowsFromResultSet(rs_).first;
        expect(row['value'], "first");
      });
    });
  }
}
