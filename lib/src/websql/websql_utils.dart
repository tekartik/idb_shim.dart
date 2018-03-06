import 'dart:web_sql';

import 'package:idb_shim/src/websql/websql_interop.dart';
import 'package:js/js_util.dart';

int getInternalVersionFromResultSet(SqlResultSet resultSet) {
  if (resultSet.rows.length > 0) {
    return resultSet.rows[0]['internal_version'];
  }
  return 0;
}

String getSignatureFromResultSet(SqlResultSet resultSet) {
  if (resultSet.rows.length > 0) {
    return resultSet.rows[0]['signature'];
  }
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
      list.add(new Map.from(sqlRow));
    }
  } catch (e) {
    // if it crashes it means it is not a dart map
    print(e);
    for (var sqlRow in rowList) {
      Map<String, dynamic> row = {};
      for (var key in objectKeys(sqlRow)) {
        // ignore: argument_type_not_assignable
        row[key] = getProperty(sqlRow, key);
      }
    }
  }
  return list;
}
