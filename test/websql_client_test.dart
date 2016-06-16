@TestOn("browser")
library websql_client_test;

import 'package:idb_shim/src/websql/websql_wrapper.dart';
import 'package:idb_shim/src/websql/websql_client_constants.dart';
import 'package:idb_shim/idb_client_websql.dart';
import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';
import 'dart:async';

String testGlobalStoreDbName = GLOBAL_STORE_DB_NAME + "_test";

class SqliteMasterRow {
  String type;
  String name;
  SqliteMasterRow(this.type, this.name);
}

bool _isSystemTable(String name) {
  if (name.startsWith("__")) {
    return true;
  }
  if (name == "sqlite_sequence") {
    return true;
  }
  return false;
}

Future<List<SqliteMasterRow>> getSqliteMasterRowsBadJs(SqlTransaction tx,
    [String where = ""]) {
  List<SqliteMasterRow> list = [];
  return tx.execute("SELECT type, name FROM sqlite_master" + where).then((rs) {
    rs.rows.forEach((Map row) {
      String name = row['name'];
      String type = row['type'];
      if (type == 'table') {
        if (_isSystemTable(name)) {
          return;
        }
      }
      list.add(new SqliteMasterRow(type, name));
    });
    return list;
  });
}

List<SqliteMasterRow> sqliteMasterRowsFromResultSet(SqlResultSet rs) {
  List<SqliteMasterRow> list = [];
  rs.rows.forEach((Map row) {
    String name = row['name'];
    String type = row['type'];
    if (type == 'table') {
      if (_isSystemTable(name)) {
        return;
      }
    }
    list.add(new SqliteMasterRow(type, name));
  });

  return list;
}

Future<SqlResultSet> getSqliteMasterRows(SqlTransaction tx,
    [String where = ""]) {
  return tx.execute("SELECT type, name FROM sqlite_master" + where);
}

List<String> tableNamesFromResultSet(SqlResultSet rs) {
  List<String> names = [];
  var rows = sqliteMasterRowsFromResultSet(rs);
  rows.forEach((row) {
    names.add(row.name);
  });
  return names;
}

Future<SqlResultSet> getTableNamesRs(SqlTransaction tx) {
  return getSqliteMasterRows(tx, " WHERE type = 'table'");
}

Future<List<String>> getTableNames(SqlTransaction tx) {
  return getTableNamesRs(tx).then((rs) {
    return tableNamesFromResultSet(rs);
  });
}

main() {
  if (SqlDatabase.supported) {
    group('websql', () {
      IdbWebSqlFactory idbFactory = new IdbWebSqlFactory();
      idbFactory.globalStoreDbName = testGlobalStoreDbName;

      SqlDatabase openGlobalStoreDatabase() {
        SqlDatabase db = sqlDatabaseFactory.openDatabase(
            testGlobalStoreDbName,
            GLOBAL_STORE_DB_VERSION,
            testGlobalStoreDbName,
            GLOBAL_STORE_DB_ESTIMATED_SIZE);
        return db;
      }

      SqlDatabase openDatabase(String name) {
        SqlDatabase db = sqlDatabaseFactory.openDatabase(
            name, DATABASE_DB_VERSION, name, GLOBAL_STORE_DB_ESTIMATED_SIZE);
        return db;
      }

      Future clearTables(SqlTransaction tx) {
        return getTableNamesRs(tx).then((SqlResultSet rs) {
          var names = tableNamesFromResultSet(rs);
          return tx.dropTablesIfExists(names);
          //      Completer completer = new Completer.sync();
          //
          //      //tx.dropTablesIfExists(names).then((_) {
          //        completer.complete();
          //      //});
          //      return completer.future;
        });
      }

      TestContext ctx = new TestContext()
        ..factory = idbFactory;

      group('tools', () {
        test('get table names rs', () {
          SqlDatabase db = openDatabase(ctx.dbName);
          return db.transaction().then((tx) {
            return getTableNamesRs(tx).then((rs) {}).then((_) {
              return getTableNamesRs(tx).then((rs) {});
            });
          });
        });

        test('get table names', () {
          SqlDatabase db = openDatabase(ctx.dbName);
          return db.transaction().then((tx) {
            return getTableNames(tx).then((_) {}).then((_) {
              return getTableNames(tx).then((_) {});
            });
          });
        });

        test('clear tables', () {
          SqlDatabase db = openDatabase(ctx.dbName);
          return db.transaction().then((tx) {
            return clearTables(tx).then((rs) {
              return getTableNamesRs(tx).then((list) {
                //expect(list, isEmpty);
              });
            });
          });
        });
      });

      group('idb_global_store', () {
        //wrapped.sqlDatabaseFactory.o
        test('open', () {
          openGlobalStoreDatabase();
        });

        test('clear_global_store_tables', () {
          SqlDatabase db = openGlobalStoreDatabase();
          return db.transaction().then((tx) {
            return clearTables(tx).then((_) {
              return getTableNamesRs(tx).then((rs) {
                var list = tableNamesFromResultSet(rs);
                expect(list, isEmpty);
              });
            });
          }).then((_) {
            return idbFactory.getDatabaseNames().then((list) {
              expect(list, isEmpty);

              // check the tables created
              return db.transaction().then((tx) {
                return getTableNamesRs(tx).then((rs) {
                  var list = tableNamesFromResultSet(rs);
                  expect(list, ['version', 'databases']);
                });
              });
            });
          });
        });

        /**
         * this handle the case where the master table is reopen with bad data in it
         */
        test('factory then clear global store tables', () {
          return idbFactory.getDatabaseNames().then((_) {
            SqlDatabase db = openGlobalStoreDatabase();
            return db.transaction().then((tx) {
              return clearTables(tx).then((_) {
                return getTableNamesRs(tx).then((rs) {
                  var list = tableNamesFromResultSet(rs);
                  expect(list, isEmpty);
                });
              });
            }).then((_) {
              return idbFactory.getDatabaseNames().then((list) {
                expect(list, isEmpty);

                // check the tables created
                return db.transaction().then((tx) {
                  return getTableNamesRs(tx).then((rs) {
                    var list = tableNamesFromResultSet(rs);
                    expect(list, ['version', 'databases']);
                  });
                });
              });
            });
          });
        });

        //    test('clear global store tables 2', () {
        //      SqlDatabase db = openGlobalStoreDatabase();
        //      return db.transaction().then((tx) {
        //        return clearTables(tx).then((_) {
        //          return getTableNames(tx).then((list) {
        //            expect(list, isEmpty);
        //          });
        //        });
        //      }).then((_) {
        //        return idbFactory.getDatabaseNames().then((list) {
        //          expect(list, isEmpty);
        //
        //          // check the tables created
        //          return db.transaction().then((tx) {
        //            return getTableNames(tx).then((list) {
        //              expect(list, ['version', 'databases']);
        //            });
        //          });
        //        });
        //      });
        //    });

        //    solo_test('check database name not removed', () {
        //      SqlDatabase db = openGlobalStoreDatabase();
        //            return db.transaction().then((tx) {
        //              return clearTables(tx);
        //            }).then((_) {
        //              // Call get database name just
        //              return idbFactory.getDatabaseNames().then((_) {
        //
        //          SqlDatabase db = openGlobalStoreDatabase();
        //          return db.transaction().then((tx) {
        //            return clearTables(tx).then((_) {
        //              tx.execute("INSERT INTO database(name) VALUES(?)", ["dummy"]);
        //            });
        //          }).then((_) {
        //            return idbFactory.getDatabaseNames().then((list) {
        //              expect(list, isEmpty);
        //            });
        //          });
        //        });
        //  });
      });

      group('idb database', () {
        //wrapped.sqlDatabaseFactory.o
        test('open', () {
          openDatabase(ctx.dbName);
        });

        test('clear database tables', () {
          SqlDatabase db = openDatabase(ctx.dbName);
          return db.transaction().then((tx) {
            return clearTables(tx).then((_) {
              return getTableNames(tx).then((list) {
                expect(list, isEmpty);
              });
            });
          }).then((_) {
            // make sure we can open it though
            return idbFactory.open(ctx.dbName).then((idb) {
              expect(idb.objectStoreNames, isEmpty);

              // check the tables created
              return db.transaction().then((tx) {
                return getTableNames(tx).then((list) {
                  expect(list, ['version', 'stores']);
                });
              });
            });
          });
        });

        test('clear one store database tables ', () {
          SqlDatabase db = openDatabase(ctx.dbName);
          return db.transaction().then((tx) {
            return clearTables(tx).then((_) {
              return getTableNames(tx).then((list) {
                expect(list, isEmpty);
              });
            });
          }).then((_) {
            // make sure we can open it though
            void _initializeDatabase(VersionChangeEvent e) {
              Database db = e.database;
              db.createObjectStore(testStoreName);
            }

            return idbFactory
                .open(ctx.dbName,
                version: 1, onUpgradeNeeded: _initializeDatabase)
                .then((idb) {
              expect(idb.objectStoreNames, [testStoreName]);

              // check the tables created
              return db.transaction().then((tx) {
                return getTableNames(tx).then((list) {
                  expect(list, ['version', 'stores', '_store_test_store']);

                  // delete the db make sure all the tables are removed
                  idb.close();
                  return idbFactory.deleteDatabase(ctx.dbName).then((_) {
                    return db.transaction().then((tx) {
                      return getTableNames(tx).then((list) {
                        expect(list, isEmpty);
                      });
                    });
                  });
                });
              });
            });
          });
        });
      });
    });
  }
}
