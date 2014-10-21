part of idb_shim_websql;

String _booleanArg(bool value) {
  return value == null ? null : (value ? "1" : "0");
}

int _getInternalVersionFromResultSet(SqlResultSet resultSet) {
  if (resultSet.rows.length > 0) {
    return resultSet.rows[0]['internal_version'];
  }
  return 0;
}
String _getSignatureFromResultSet(SqlResultSet resultSet) {
  if (resultSet.rows.length > 0) {
    return resultSet.rows[0]['signature'];
  }
  return null;
}

