@TestOn("browser")
library websql_wrapper_test;

import 'package:test/test.dart';
import 'package:idb_shim/src/websql/websql_wrapper.dart';

main() {
  group('wrapper', () {
    //wrapped.sqlDatabaseFactory.o
    test('open', () {
      SqlDatabase db = sqlDatabaseFactory.openDatabase(
          "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
      expect(db, isNotNull);
      //wrapped.SqlTransaction transaction = db.transaction();
    });

    test('transaction', () {
      SqlDatabase db = sqlDatabaseFactory.openDatabase(
          "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
      return db.transaction().then((SqlTransaction transaction) {
        transaction.execute("DROP TABLE IF EXISTS test");
        return transaction.completed;
      });
    });

    test('select 1', () {
      SqlDatabase db = sqlDatabaseFactory.openDatabase(
          "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
      return db.transaction().then((SqlTransaction transaction) {
        transaction.execute("SELECT 0 WHERE 0 = 1").then((rs) {
          expect(rs.rows.length, 0);
          return transaction.completed;
        });
      });
    });

    test('transaction 2 actions', () {
      SqlDatabase db = sqlDatabaseFactory.openDatabase(
          "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
      return db.transaction().then((SqlTransaction transaction) {
        return transaction.execute("DROP TABLE IF EXISTS test").then((_) {
          return transaction.execute("CREATE TABLE test (name TEXT)").then((_) {
            return transaction.completed;
          });
        });
      });
    });
  });
}
