part of idb_websql;

class _WebSqlIndexMeta {
  _WebSqlObjectStoreMeta storeMeta;
  String name;
  String keyPath;
  bool unique;
  bool multiEntry;
  _WebSqlIndexMeta(this.storeMeta, this.name, this.keyPath, this.unique, this.multiEntry) {
    multiEntry = (multiEntry == true);
    unique = (unique == true);
  }

  @override
  String toString() {
    return "index $name on $keyPath unique ${unique} multi ${multiEntry}";
  }
  
  String get keyColumn => storeMeta.sqlColumnName(keyPath);
}

class _WebSqlIndex extends Index {
  _WebSqlIndexMeta _meta;
  _WebSqlIndexMeta get meta => _meta;
  _WebSqlObjectStore store;
  
  @override
  String get name => _meta.name;

  @override
  String get keyPath => _meta.keyPath;
  
  @override
  bool get unique => _meta.unique;
  
  @override
  bool get multiEntry => _meta.multiEntry;


  String get keyColumn => _meta.keyColumn;
  String get sqlIndexName => store.getSqlIndexName(keyPath);
  String get sqlTableName => store.sqlTableName;
  
  // Ordered keys
  List keys = new List();

  _WebSqlTransaction get transaction => store.transaction;

  

  static String indeciesToString(Map<String, _WebSqlIndexMeta> indecies) {
    if (indecies.isEmpty) {
      return null;
    }
    List list = new List();
    indecies.values.forEach((_WebSqlIndexMeta indexMeta) {
      Map indexDef = new Map();
      indexDef['name'] = indexMeta.name;
      indexDef['key_path'] = indexMeta.keyPath;
      indexDef['multi_entry'] = indexMeta.multiEntry;
      indexDef['unique'] = indexMeta.unique;
      list.add(indexDef);
    });
    return JSON.encode(list);
  }

  /**
   * data can null, it will be lazy loaded
   */
  _WebSqlIndex(this.store, this._meta) {
    // Build the index based on the existing
    // TODO
    //devPrint("${store} ${_meta}");
  }
 
  Future create() {
    String sqlTableName = this.sqlTableName;
    String sqlIndexName = this.sqlIndexName;
    String alterSql = "ALTER TABLE ${sqlTableName} ADD ${keyColumn} BLOB";
    String updateSql = "UPDATE stores SET indecies = ? WHERE name = ?";

    List updateArgs = [indeciesToString(store._meta.indecies), store.name];
    return transaction.execute(alterSql).then((_) {
      return transaction.execute(updateSql, updateArgs);
    }).then((_) {
      // Drop the index if needed


      String dropIndexSql = "DROP INDEX IF EXISTS $sqlIndexName";
      return transaction.execute(dropIndexSql).then((_) {

        // create the index
        StringBuffer sb = new StringBuffer();
        sb.write("CREATE ");
        if (unique) {
          sb.write("UNIQUE ");
        }
        sb.write("INDEX $sqlIndexName ON $sqlTableName ($keyColumn)");
        String createIndexSql = sb.toString();

        return transaction.execute(createIndexSql);

      });

    });
  }

  Future _checkIndex(computation()) {
    return store._checkStore(computation);
  }

  Future<SqlResultSet> execute(String statement, [List args]) {
    return store.execute(statement, args);
  }

  Future<int> count([key_OR_range]) {
    return _checkIndex(() {
      _CountQuery query = new _CountQuery(sqlTableName, keyColumn, key_OR_range);
      return query.count(transaction);
    });
  }

  Stream<Cursor> openKeyCursor({key, KeyRange range, String direction, bool autoAdvance}) {

    _WebSqlKeyIndexCursorController ctlr = new _WebSqlKeyIndexCursorController(this, direction, autoAdvance);

    // Future
    _checkIndex(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }


  @override
  Future get(key) {
    return _checkIndex(() {
      return store._get(key, keyPath);
    });
  }

  @override
  Future getKey(key) {
    return _checkIndex(() {
      return store._getKey(key, keyPath);
    });
  }

  @override
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    _WebSqlIndexCursorWithValueController ctlr = new _WebSqlIndexCursorWithValueController(this, direction, autoAdvance);

    // Future
    _checkIndex(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }
}
