part of idb_shim_websql;

/**
 * 
 */
class _WebSqlGlobalStore {
  // To allow for proper schema migration if needed
  static const int INTERNAL_VERSION = 1;

  // can be changed for testing
  String dbName = _DB_NAME;
  static String _DB_NAME = GLOBAL_STORE_DB_NAME;
  static String dbVersion = GLOBAL_STORE_DB_VERSION;
  static int dbEstimatedSize = GLOBAL_STORE_DB_ESTIMATED_SIZE;
  static String nameColumnName = "name";
  static String databasesTableName = "databases";

  SqlDatabase db;

  Future<List<String>> getDatabaseNames() {
    return _checkOpenTransaction().then((tx) {
      return tx
          .execute("SELECT $nameColumnName FROM $databasesTableName")
          .then((SqlResultSet resultSet) {
        List<String> names = [];
        resultSet.rows.forEach((Map row) {
          //print(row);
          names.add(row[nameColumnName] as String);
        });
        return names;
      });
    }).catchError((e) {
      // Ok to fail
      return List<String>();
    });
  }

  Future createDatabasesTable(SqlTransaction tx) {
    return tx.execute("DROP TABLE IF EXISTS $databasesTableName").then((_) {
      return tx.execute(
          "CREATE TABLE $databasesTableName ($nameColumnName TEXT UNIQUE NOT NULL)");
    });
  }

  Future addDatabaseName(String name) {
    Future<SqlResultSet> insert(SqlTransaction tx) {
      String insertSqlStatement =
          "INSERT INTO $databasesTableName ($nameColumnName) VALUES(?)";
      List<String> insertSqlArguments = [name];
      return tx.execute(insertSqlStatement, insertSqlArguments);
    }

    Future<bool> checkExists(SqlTransaction tx) {
      return tx.selectCount("databases WHERE name = ?", [name]).then((count) {
        return count == 1;
      });
    }

    return _checkOpenTransaction().then((tx) {
      return checkExists(tx).then((exists) {
        if (!exists) {
          return insert(tx);
        }
        return null;
      });
    });
  }

  Future deleteDatabaseName(String name) {
    return _checkOpenTransaction().then((tx) {
      String deleteSqlStatement =
          "DELETE FROM $databasesTableName WHERE $nameColumnName ";
      List<String> deleteSqlArguments;
      if (name == null) {
        deleteSqlStatement += "IS NULL";
        deleteSqlArguments = [];
      } else {
        deleteSqlStatement += "= ?";
        deleteSqlArguments = [name];
      }

      return tx
          .execute(deleteSqlStatement, deleteSqlArguments)
          .then((SqlResultSet resultSet) {
        //print(resultSet.rowsAffected);
      });
    }).catchError((e) {
      // Ok to fail
      return null;
    });
  }

  /**
   * There is valid transaction right aways
   */
  Future<SqlTransaction> _checkOpenTransaction() {
    return _checkOpen().then((SqlTransaction tx) {
      if (tx == null) {
        return db.transaction();
      }
      return tx;
    });
  }

  Future<SqlTransaction> _checkOpen() {
    var completer = Completer<SqlTransaction>.sync();
    _checkOpenNew((SqlTransaction tx) {
      completer.complete(tx);
    });
    return completer.future;
  }

  void _checkOpenNew(void action(SqlTransaction tx)) {
    if (db == null) {
      db = sqlDatabaseFactory.openDatabase(
          dbName, dbVersion, dbName, dbEstimatedSize);
    }

    Future<SqlTransaction> _cleanup(SqlTransaction tx) {
      return tx.dropTableIfExists("version") //
          .then((_) {
        return tx.execute(
            "CREATE TABLE version (internal_version INT, signature TEXT)");
      }).then((_) {
        return tx.execute(
            "INSERT INTO version (internal_version, signature)" //
            " VALUES (?, ?)",
            [INTERNAL_VERSION, INTERNAL_SIGNATURE]);
      }).then((_) {
        return createDatabasesTable(tx).then((_) {
          return tx;
        });
      });
    }

    Future<SqlTransaction> _setup() {
      return db.transaction().then((tx) async {
        try {
          SqlResultSet rs = await tx
              .execute("SELECT internal_version, signature FROM version"); //
          if (rs.rows.length != 1) {
            return await _cleanup(tx);
          }
          int internalVersion = getInternalVersionFromResultSet(rs);
          String signature = getSignatureFromResultSet(rs);
          if (signature != INTERNAL_SIGNATURE) {
            return await _cleanup(tx);
          }
          if (internalVersion != INTERNAL_VERSION) {
            return await _cleanup(tx);
          }
          return tx;
        } catch (_) {
          //return db.transaction().then((tx) {
          return await _cleanup(tx);
          //});
        }
      });
    }

    _setup().then((tx) {
      action(tx);
    });
  }
}
