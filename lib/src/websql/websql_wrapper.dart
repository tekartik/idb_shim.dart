library idb_shim_websql_wrapper;

import 'dart:web_sql' as wql;
import 'dart:web_sql' show SqlResultSet, SqlError;
export 'dart:web_sql' show SqlResultSet, SqlError, SqlResultSetRowList;
import 'dart:html' as html;
import 'dart:async';

class SqlDatabaseFactory {

  SqlDatabase openDatabase(String name, String version, String displayName, int estimatedSize, [html.DatabaseCallback creationCallback]) {
    wql.SqlDatabase database = html.window.openDatabase(name, version, displayName, estimatedSize, creationCallback);
    if (database == null) {
      return null;
    }
    return new SqlDatabase(database, name, version, displayName, estimatedSize);
  }
}

SqlDatabaseFactory _sqlDatabaseFactory;

SqlDatabaseFactory get sqlDatabaseFactory {
  if (_sqlDatabaseFactory == null) {
    _sqlDatabaseFactory = new SqlDatabaseFactory();
  }
  return _sqlDatabaseFactory;

}

class SqlDatabase {
  
  @deprecated
  static set debug(bool debug) => _DEBUG = debug;
  
  static bool get DEBUG => _DEBUG;
  static bool _DEBUG = false;
  static int _DEBUG_ID = 0;

  static bool get supported {
    return wql.SqlDatabase.supported;
  }


  int _debugId;

  wql.SqlDatabase _sqlDatabase;
  SqlDatabase(this._sqlDatabase, String _name, String _version, String _displayName, int _estimatedSize) {
    //debug = true; // to remove
    if (_DEBUG) {
      _debugId = ++_DEBUG_ID;
      debugLog("openDatabase $_debugId $_displayName(${_name}, $_version, $_estimatedSize)");
    }
  }

  void debugLog(String msg) {
    String timeText = new DateTime.now().toIso8601String().substring(18);
    print("$timeText $_debugId $msg");
  }

  Future<SqlTransaction> transaction() {
    Completer completer = new Completer.sync();
    _sqlDatabase.transaction((txn) {
      if (_DEBUG) {
        debugLog("BEGIN TRANSACTION");
      }
      completer.complete(new SqlTransaction(this, txn));
    });
    return completer.future;
  }
}

class SqlTransaction {

  SqlDatabase _database;
  var _sqlTxn;
  //wql.SqlTransaction _sqlTxn;
  static List<Object> EMPTY_ARGS = [];
  SqlTransaction(this._database, this._sqlTxn);
  Future<SqlResultSet> execute(String sqlStatement, [List<Object> arguments]) {

    _beginOperation();
    String getStatementToString() {
      String text = sqlStatement;

      int index = 0;
      while (index < arguments.length) {
        text = text.replaceFirst('?', arguments[index++].toString());
      }
      return text;
    }

    Completer completer = new Completer.sync();
    if (arguments == null) {
      arguments = EMPTY_ARGS;
    }

    if (SqlDatabase._DEBUG) {
      _database.debugLog(getStatementToString());
    }
    _sqlTxn.executeSql(sqlStatement, arguments, (txn, SqlResultSet rs) {
      if (SqlDatabase._DEBUG) {
        //_database.debugLog(getStatementToString());
        String upperCaseStatement = sqlStatement.toUpperCase();
        if (upperCaseStatement.startsWith("INSERT")) {
          _database.debugLog("  inserted id ${rs.insertId}");
        } else if (upperCaseStatement.startsWith("DELETE")) {
          _database.debugLog("  deleted ${rs.rowsAffected}");
        } else if (upperCaseStatement.startsWith("UPDATE")) {
          _database.debugLog("  updated ${rs.rowsAffected}");
        } else if (upperCaseStatement.startsWith("SELECT")) {
          if (rs.rows.length == 0) {
            _database.debugLog("  empty");
          }
          rs.rows.forEach((Map map) {
            _database.debugLog("- $map");
          });
        }
        //        else if (upperCaseStatement.startsWith("CREATE TABLE")) {
        //          print("  updated ${rs.rowsAffected}");
        //        }


        // if (upperCaseStatement.startsWith("CREATE TABLE")) {
        // nothing interesting: rowsAffected 0, insertId 0

        // else if (upperCaseStatement.startsWith("DROP TABLE")) {
        // nothing interesting: rowsAffected 0

      }
      _endOperation();
      completer.complete(rs);
    }, (txn, SqlError error) {
      if (SqlDatabase._DEBUG) {
        _database.debugLog(error.message + "(${error.code}) executing " + getStatementToString());
      }
      _endOperation();
      completer.completeError(error);
    });
    return completer.future;
  }

  Future dropTableIfExists(String name) {
    return execute("DROP TABLE IF EXISTS $name");
  }

  Future dropTablesIfExists(List<String> names) {
    int i = 0;
    Completer completer = new Completer.sync();
    dropNextTable() {
      if (i < names.length) {
        String name = names[i++];
        return dropTableIfExists(name).then((_) {
          return dropNextTable();
        });
      }
      completer.complete();
    }
    dropNextTable();
    return completer.future;

  }
  /**
   * selectCount("table WHERE value > 2");
   */

  Future<int> selectCount(String from, [List<Object> arguments]) {
    return execute("SELECT COUNT(*) as _count FROM " + from, arguments).then((rs) {
      return rs.rows[0]['_count'];
    });

  }
  void commit() {
    if (SqlDatabase._DEBUG) {
      _database.debugLog("COMMIT");
    }
  }

  /**
   * ok that's ugly but in js websql transaction failed as soon as we have a future...
   * so to use when no functions are performed
   * 
   * needed for cursor with manual advance
   */
  Future ping() {
    return execute("SELECT 0 WHERE 0 = 1");
  }

  Completer<SqlTransaction> _completer = new Completer();

  void _asyncCompleteIfDone() {
    if (_operationCount == 0) {
      new Future(_completeIfDone);
    }
  }

  void _completeIfDone() {
    if (_operationCount == 0) {

      complete();
    }
  }

  void complete() {
    if (_operationCount != null) {
      commit();
      // This is an extra debug check
      // that sometimes put the mess...
      _operationCount = null;
    }
    if (!_completer.isCompleted) {
      _completer.complete(this);
    }

  }

  Future<SqlTransaction> get completed {
    // This take care of empty transaction
    _asyncCompleteIfDone();
    return _completer.future;
  }

  int _operationCount = 0;

  /**
       * must be used in pair
       */
  void _beginOperation() {
    _operationCount++;
  }

  void _endOperation() {
    --_operationCount;
    // Make it breath
    _asyncCompleteIfDone();
  }

}
