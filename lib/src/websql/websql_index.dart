part of idb_websql;

class _WebSqlIndexData {
  String keyPath;
  bool unique;
  bool multiEntry;
  _WebSqlIndexData(this.keyPath, this.unique, this.multiEntry);
}

class _WebSqlIndex extends Index {
  _WebSqlIndexData data;
  _WebSqlObjectStore store;
  String name;

  String get keyPath => data.keyPath;
  bool get unique => data.unique;
  bool get multiEntry => data.multiEntry;


  String get sqlIndexName => store.getSqlIndexName(keyPath);
  String get sqlTableName => store.sqlTableName;
  String get keyColumn => store.sqlColumnName(keyPath);
  // Ordered keys
  List keys = new List();

  _WebSqlTransaction get transaction => store.transaction;

  /**
   * indecies <=> String
   */
  static Map<String, _WebSqlIndexData> indeciesDataFromString(String indeciesText) {
    Map indeciesData = new Map();

    if (indeciesText != null) {
      List indexList = JSON.decode(indeciesText);
      indexList.forEach((Map indexDef) {
        String name = indexDef['name'];
        String keyPath = indexDef['key_path'];
        bool multiEntry = indexDef['multi_entry'];
        bool unique = indexDef['unique'];
        indeciesData[name] = new _WebSqlIndexData(keyPath, unique, multiEntry);
      });
    }
    return indeciesData;
  }

  static String indeciesToString(Map<String, _WebSqlIndex> indecies) {
    if (indecies.isEmpty) {
      return null;
    }
    List list = new List();
    indecies.values.forEach((_WebSqlIndex index) {
      Map indexDef = new Map();
      indexDef['name'] = index.name;
      indexDef['key_path'] = index.keyPath;
      indexDef['multi_entry'] = index.multiEntry;
      indexDef['unique'] = index.unique;
      list.add(indexDef);
    });
    return JSON.encode(list);
  }

  /**
   * data can null, it will be lazy loaded
   */
  _WebSqlIndex(this.store, this.name, this.data) {
    // Build the index based on the existing
    // TODO
  }
  //                 var columnName = indexName;
  //                 idxList[indexName] = {
  //                     "columnName": columnName,
  //                     "keyPath": keyPath,
  //                     "optionalParams": optionalParameters
  //                 };
  //                 // For this index, first create a column
  //                 me.__idbObjectStore.__storeProps.indexList = JSON.stringify(idxList);
  //                 var sql = ["ALTER TABLE", idbModules.util.quote(me.__idbObjectStore.name), "ADD", columnName, "BLOB"].join(" ");
  //                 idbModules.DEBUG && console.log(sql);
  //                 tx.executeSql(sql, [], function(tx, data){
  //                     // Once a column is created, put existing records into the index
  //                     tx.executeSql("SELECT * FROM " + idbModules.util.quote(me.__idbObjectStore.name), [], function(tx, data){
  //                         (function initIndexForRow(i){
  //                             if (i < data.rows.length) {
  //                                 try {
  //                                     var value = idbModules.Sca.decode(data.rows.item(i).value);
  //                                     var indexKey = eval("value['" + keyPath + "']");
  //                                     tx.executeSql("UPDATE " + idbModules.util.quote(me.__idbObjectStore.name) + " set " + columnName + " = ? where key = ?", [idbModules.Key.encode(indexKey), data.rows.item(i).key], function(tx, data){
  //                                         initIndexForRow(i + 1);
  //                                     }, error);
  //                                 }
  //                                 catch (e) {
  //                                     // Not a valid value to insert into index, so just continue
  //                                     initIndexForRow(i + 1);
  //                                 }
  //                             }
  //                             else {
  //                                 idbModules.DEBUG && console.log("Updating the indexes in table", me.__idbObjectStore.__storeProps);
  //                                 tx.executeSql("UPDATE __sys__ set indexList = ? where name = ?", [me.__idbObjectStore.__storeProps.indexList, me.__idbObjectStore.name], function(){
  //                                     me.__idbObjectStore.__setReadyState("createIndex", true);
  //                                     success(me);
  //                                 }, error);
  //                             }
  //                         }(0));
  //                     }, error);
  //                 }, error);
  //             }, "createObjectStore");


  Future create() {
    String sqlTableName = this.sqlTableName;
    String sqlIndexName = this.sqlIndexName;
    String alterSql = "ALTER TABLE ${sqlTableName} ADD ${keyColumn} BLOB";
    String updateSql = "UPDATE stores SET indecies = ? WHERE name = ?";

    List updateArgs = [indeciesToString(store.indecies), store.name];
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
    //       String createSql = "CREATE TABLE $_tableName (${keyColumn} " + (autoIncrement ? "INTEGER PRIMARY KEY AUTOINCREMENT" : "BLOB PRIMARY KEY") + ", $VALUE_COLUMN_NAME BLOB)";
    //       String insertStore = "INSERT INTO stores (name, key_path, auto_increment) VALUES (?, ?, ?)";
    //       List insertStoreArgs = [name, keyPath, booleanArg(autoIncrement)];
    //
    //       return transaction.execute(dropSql).then((_) {
    //         return transaction.execute(createSql);
    //       }).then((_) {
    //         return transaction.execute(insertStore, insertStoreArgs);
    //       });
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
