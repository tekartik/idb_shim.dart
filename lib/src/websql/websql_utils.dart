part of idb_shim_websql;

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
