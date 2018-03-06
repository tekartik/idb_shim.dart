@TestOn("browser")
library websql_raw_test;

import 'package:dev_test/test.dart';

import 'idb_test_common.dart';
//import 'dart:web_sql';

main() {
  /*
  if (SqlDatabase.supported) {
    group('websql_js', () {
      test('raw', () async {
        SqlDatabase db = openDatabase(
            "websql_js_raw_test_1", "1", "WebSql js raw test 1", 50 * 1000);
        SqlResultSet rs_;
        SqlResultSet insertRs_;
        SqlResultSet deleteRs_;

        devPrint("1");
        var futureResult = db.transaction((txn) async {
          devPrint("2");
          await txn.executeSql("DROP TABLE IF EXISTS test");
          await txn.executeSql("CREATE TABLE test (value TEXT)");
          insertRs_ = await txn
              .executeSql("INSERT INTO test (value) VALUES (?)", ["first"]);
          rs_ = await txn.executeSql("SELECT * FROM test");
          deleteRs_ = await txn.executeSql("DELETE FROM test");
          return 1234;
        });

        var result = await futureResult;
        devPrint("result $result");
        devPrint("inserted: ${insertRs_.insertId}");

        expect(insertRs_.insertId, 1);

        devPrint("rs_ ${rs_.rows}");
        // We should get a single row {"value": "first"}
        var row = getRowsFromResultSet(rs_).first;
        expect(row['value'], "first");

        expect(deleteRs_.rowsAffected, 1);
      });
    });

    test('error', () async {
      SqlDatabase db = openDatabase(
          "websql_js_raw_version", "1", "WebSql js raw version", 50 * 1000);

      try {
        SqlResultSet rs = await db.readTransaction((txn) {
          return txn.executeSql("SELECT * FROM test");
        });

        fail("should fail");
      } on SqlError catch (e) {
        expect(e.message, contains("no such table"));
        expect(e.code, 5);
      }
    });
  }
  */
}
