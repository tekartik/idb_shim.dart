@TestOn("browser")
library websql_raw_test;

import 'dart:async';
import 'dart:html';
import 'dart:web_sql';
import 'package:dev_test/test.dart';

main() {
  if (SqlDatabase.supported) {
    group('websql_raw', () {
      test('open', () async {
        SqlDatabase db = window.openDatabase(
            "websql_raw_test", "1", "WebSql raw test", 50 * 1000);
        var completer = new Completer();
        db.transaction(
            (txn) {
              txn.executeSql("DROP TABLE IF EXISTS test");
            },
            null,
            () {
              completer.complete(null);
            });
        await completer.future;
      });
    });
  }
}
