@TestOn("browser")
library websql_raw_test;

import 'dart:async';
import 'dart:html';
import 'dart:web_sql';

import 'package:dev_test/test.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:idb_shim/src/websql/websql_utils.dart';

void main() {
  if (SqlDatabase.supported) {
    group('websql_raw', () {
      test('bug_dart2.0.0-dev', () async {
        SqlDatabase db = window.openDatabase(
            "websql_raw_test_2", "1", "WebSql raw test 2", 50 * 1000);
        var completer = Completer();
        SqlResultSet rs_;

        db.transaction((txn) {
          txn.executeSql("DROP TABLE IF EXISTS test", []).then((_) {
            txn.executeSql("CREATE TABLE test (value TEXT)", []).then((__) {
              txn.executeSql(
                  "INSERT INTO test (value) VALUES (?)", ["first"]).then((___) {
                txn.executeSql("SELECT * FROM test", []).then(
                    (SqlResultSet rs) {
                  rs_ = rs;
                });
              });
            });
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

      /*
      test('for_dart2.0.0-dev', () async {
        SqlDatabase db = window.openDatabase(
            "websql_raw_test_2", "1", "WebSql raw test 2", 50 * 1000);
        SqlResultSet rs_;

        await db.transaction((txn) async {
          await txn.executeSql("DROP TABLE IF EXISTS test");
          await txn.executeSql("CREATE TABLE test (value TEXT)");
          await txn.executeSql("INSERT INTO test (value) VALUES (?)", ["first"]);
          rs_ = await txn.executeSql("SELECT * FROM test");
        });

        // We should get a single row {"value": "first"}
        devPrint("result set: ${rs_}");
        var row = getRowsFromResultSet(rs_).first;
        expect(row['value'], "first");
      });
      */
    });
  }
}
