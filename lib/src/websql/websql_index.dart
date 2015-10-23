part of idb_shim_websql;

/*
class _WebSqlIndexMeta extends IdbIndexMeta {
  _WebSqlObjectStoreMeta storeMeta;
  _WebSqlIndexMeta(
      this.storeMeta, String name, String keyPath, bool unique, bool multiEntry) : super(name, keyPath, unique, multiEntry);

  String get keyColumn => storeMeta.sqlColumnName(keyPath);
}
*/

class _WebSqlIndex extends Index with IndexWithMetaMixin {
  _WebSqlObjectStore store;
  final IdbIndexMeta meta;

  String _keyColumn;
  String get keyColumn {
    if (_keyColumn == null) {
      _keyColumn = store.sqlColumnName(keyPath);
    }
    return _keyColumn;
  }

  String get sqlIndexName => store.getSqlIndexName(keyPath);
  String get sqlTableName => store.sqlTableName;

  // Ordered keys
  List keys = new List();

  _WebSqlTransaction get transaction => store.transaction;

  /**
   * data can null, it will be lazy loaded
   */
  _WebSqlIndex(this.store, this.meta) {
    // Build the index based on the existing
    // TODO
    //devPrint("${store} ${_meta}");
  }

  Future create() async {
    String sqlTableName = this.sqlTableName;
    String sqlIndexName = this.sqlIndexName;
    String alterSql = "ALTER TABLE ${sqlTableName} ADD ${keyColumn} BLOB";
    String updateSql = "UPDATE stores SET meta = ? WHERE name = ?";

    // update meta in store
    await store.update();

    // add column
    await transaction.execute(alterSql);

    // Drop the index if needed

    String dropIndexSql = "DROP INDEX IF EXISTS $sqlIndexName";
    await transaction.execute(dropIndexSql);
    // create the index
    StringBuffer sb = new StringBuffer();
    sb.write("CREATE ");
    if (unique) {
      sb.write("UNIQUE ");
    }
    sb.write("INDEX $sqlIndexName ON $sqlTableName ($keyColumn)");
    String createIndexSql = sb.toString();

    await transaction.execute(createIndexSql);
  }

  Future _checkIndex(computation()) {
    return store._checkStore(computation);
  }

  Future<SqlResultSet> execute(String statement, [List args]) {
    return store.execute(statement, args);
  }

  Future<int> count([key_OR_range]) {
    return _checkIndex(() {
      _CountQuery query =
          new _CountQuery(sqlTableName, keyColumn, key_OR_range);
      return query.count(transaction);
    });
  }

  Stream<Cursor> openKeyCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    _WebSqlKeyIndexCursorController ctlr =
        new _WebSqlKeyIndexCursorController(this, direction, autoAdvance);

    // Future
    _checkIndex(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }

  @override
  Future get(key) {
    checkKeyParam(key);
    return _checkIndex(() {
      return store._get(key, keyPath);
    });
  }

  @override
  Future getKey(key) {
    checkKeyParam(key);
    return _checkIndex(() {
      return store._getKey(key, keyPath);
    });
  }

  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    _WebSqlIndexCursorWithValueController ctlr =
        new _WebSqlIndexCursorWithValueController(this, direction, autoAdvance);

    // Future
    _checkIndex(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }
}
