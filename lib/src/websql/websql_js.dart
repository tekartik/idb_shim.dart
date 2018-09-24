import 'dart:async';
import 'dart:collection';

import 'package:js/js.dart';
import 'package:js/js_util.dart';

import 'websql_interop.dart' as js;

class SqlError {
  final js.JsWebSqlError jsObject;

  SqlError(this.jsObject);

  String get message => jsObject.message;

  int get code => jsObject.code;

  @override
  String toString() => "$code $message";
}

class SqlTransaction {
  final js.JsWebSqlTransaction jsObject;

  SqlTransaction._(this.jsObject);

  Future<SqlResultSet> executeSql(String sql, [List arguments]) {
    var completer = Completer<SqlResultSet>.sync();
    jsObject.executeSql(sql, arguments, allowInterop((txn, result) {
      if (result == null) {
        completer.complete(null);
      } else {
        completer.complete(SqlResultSet._(result as js.JsWebSqlResultSet));
      }
    }), allowInterop((txn, error) {
      completer.completeError(SqlError(error as js.JsWebSqlError));
    }));
    return completer.future;
  }
}

class SqlResultSetRowList extends ListBase<Map> {
  final js.JsWebSqlResultSetRowList jsObject;

  SqlResultSetRowList._(this.jsObject);

  @override
  int get length => jsObject.length;

  @override
  Map operator [](int index) {
    return jsObject.item(index) as Map;
  }

  @override
  void operator []=(int index, Map value) {
    throw Exception("read-only");
  }

  @override
  set length(int newLength) {
    throw Exception("read-only");
  }
}

class SqlResultSet {
  final js.JsWebSqlResultSet jsObject;

  SqlResultSet._(this.jsObject);

  int get insertId => jsObject.insertId;

  SqlResultSetRowList get rows {
    if (jsObject.rows == null) {
      return null;
    } else {
      return SqlResultSetRowList._(jsObject.rows);
    }
  }

  int get rowsAffected => jsObject.rowsAffected;
}

class SqlDatabase {
  final js.JsWebSqlDatapabase jsObject;

  static bool get supported => js.openDatabase != null;

  SqlDatabase._(this.jsObject);

  Future<T> transaction<T>(FutureOr<T> action(SqlTransaction txn)) {
    FutureOr<T> result;
    var completer = Completer<T>();
    jsObject.transaction(allowInterop((jsTxn) {
      result = action(SqlTransaction._(jsTxn as js.JsWebSqlTransaction));
    }), allowInterop((error) {
      completer.completeError(error);
    }), allowInterop(() {
      completer.complete(result);
    }));
    return completer.future;
  }

  Future<T> readTransaction<T>(FutureOr<T> action(SqlTransaction txn)) {
    FutureOr<T> result;
    var completer = Completer<T>();
    jsObject.transaction(allowInterop((jsTxn) {
      result = action(SqlTransaction._(jsTxn as js.JsWebSqlTransaction));
    }), allowInterop((error) {
      completer.completeError(error);
    }), allowInterop(() {
      completer.complete(result);
    }));
    return completer.future;
  }
}

SqlDatabase openDatabase(
    String name, String version, String displayName, int estimatedSize,
    [callback(database)]) {
  js.JsWebSqlDatapabase jsWebSqlDatapabase = js.openDatabase(
      name,
      version,
      displayName,
      estimatedSize,
      callback != null ? allowInterop(callback) : null);
  print(jsWebSqlDatapabase);
  /*
  if (jsWebSqlDatapabase != null) {
    return new SqlDatabase._(jsWebSqlDatapabase);
  }
  */
  return null;
}

List<Map<String, dynamic>> getRowsFromResultSet(SqlResultSet resultSet) {
  // copy the map
  // in dart we have a list of map, in js we have a list of js object
  SqlResultSetRowList rowList = resultSet.rows;
  if (rowList == null) {
    return null;
  }
  List<Map<String, dynamic>> list = [];

  // try access, only work on dart
  try {
    for (var sqlRow in rowList) {
      list.add(Map.from(sqlRow));
    }
  } catch (e) {
    // if it crashes it means it is not a dart map
    print(e);
    for (var sqlRow in rowList) {
      Map<String, dynamic> row = {};
      for (var key in js.objectKeys(sqlRow)) {
        // ignore: argument_type_not_assignable
        row[key] = getProperty(sqlRow, key);
      }
    }
  }
  return list;
}
