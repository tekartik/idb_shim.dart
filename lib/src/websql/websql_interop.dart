@JS()
library idb_shim.websql.websql_interop;

import 'package:js/js.dart';

@JS("Object.keys")
external List<String> objectKeys(Object obj);

@anonymous
@JS()
class JsWebSqlTransaction {
  external executeSql(String sql, List arguments, callback(txn, result),
      errorCallback(txn, error));
}

@anonymous
@JS()
class JsWebSqlResultSetRowList {
  external dynamic item(int index);
  external int get length;
}

@anonymous
@JS()
class JsWebSqlResultSet {
  external int get insertId;

  external JsWebSqlResultSetRowList get rows;

  external int get rowsAffected;
}

@anonymous
@JS()
class JsWebSqlDatapabase {
  external transaction(
      txnCallback(txn), errorCallback(error), successCallback());

  external readtransaction(
      txnCallback(txn), errorCallback(error), successCallback());
}

@JS("window.openDatabase")
external JsWebSqlDatapabase openDatabase(
    String name, String version, String displayName, int estimatedSize,
    [callback(database)]);

@anonymous
@JS()
class JsWebSqlError {
  external int get code;
  external String get message;
}
