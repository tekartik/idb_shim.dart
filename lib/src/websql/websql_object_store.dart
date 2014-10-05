part of idb_websql;

class _WebSqlObjectStoreMeta {

}
class _WebSqlObjectStore extends ObjectStore {

  _WebSqlTransaction transaction;
  String name;
  String keyPath;
  bool autoIncrement;
  Map<String, Index> indecies = new Map();
  _WebSqlObjectStoreMeta _meta;

  _WebSqlDatabase get database => transaction.database;

  bool get ready => keyColumn != null;
  Future _lazyPrepare;
  /*
  Future get initialization {
    if (_initialization == null) {
      return new Future.value();
    } else {
      return _initialization;
    }

  }
  */

  _WebSqlObjectStore(this.name, this.transaction, this.keyPath, this.autoIncrement) {
    autoIncrement = (autoIncrement == true);
    //devPrint(keyPath);

  }

  static const String VALUE_COLUMN_NAME = 'value';
  static const String KEY_DEFAULT_COLUMN_NAME = 'key';

  // If null this means we need to load from database
  String keyColumn;

  String get sqlTableName {
    return getSqlTableName(name);
  }

  String getSqlIndexName(String keyPath) {
    return "_index_${name}_${keyPath}";
  }

  static String getSqlTableName(String storeName) {
    return "_store_$storeName";
  }

//  static String getSqlIndexName(String storeName) {
//      return "_index_$storeName";
//    }

  String sqlColumnName(String keyPath) {
    if (keyPath == null) {
      return KEY_DEFAULT_COLUMN_NAME;
    } else {
      return "_col_$keyPath";
    }

  }

  Future<SqlResultSet> execute(String statement, [List args]) {
    return transaction.execute(statement, args);
  }

  void _initOptions(String keyPath, bool autoIncrement) {

    this.autoIncrement = (autoIncrement != null && autoIncrement);
    this.keyPath = keyPath;

    this.keyColumn = sqlColumnName(keyPath);
  }

  Future _deleteTable(_WebSqlTransaction transaction) {
    String dropSql = "DROP TABLE IF EXISTS $sqlTableName";
    return transaction.execute(dropSql);
  }
  Future create() {

    _initOptions(keyPath, autoIncrement);

    // Here don't call _addRequest as we don't want to load from db

    String createSql = "CREATE TABLE $sqlTableName (${keyColumn} " + (autoIncrement ? "INTEGER PRIMARY KEY AUTOINCREMENT" : "BLOB PRIMARY KEY") + ", $VALUE_COLUMN_NAME BLOB)";
    String insertStore = "INSERT INTO stores (name, key_path, auto_increment) VALUES (?, ?, ?)";
    List insertStoreArgs = [name, keyPath, _booleanArg(autoIncrement)];

    return _deleteTable(transaction).then((_) {
      return transaction.execute(createSql);
    }).then((_) {
      return transaction.execute(insertStore, insertStoreArgs);
    });

  }

  Future _checkWritableStore(Future computation()) {
    if (transaction._mode != IDB_MODE_READ_WRITE) {
      return new Future.error(new DatabaseReadOnlyError());
    }
    return _checkStore(computation);
  }

  Future _checkStore(Future computation()) {

    // this is also an indicator
    if (!ready) {
      if (_lazyPrepare == null) {
        // Make sure the db was not upgrade
        // TODO do this at the beginning of each transaction
        var sqlSelect = "SELECT value FROM version WHERE value > ?";
        var sqlArgs = [database.version];
        _lazyPrepare = execute(sqlSelect, sqlArgs).then((SqlResultSet rs) {
          if (rs.rows.length > 0) {
            // Send an onVersionChange event
            //Map map = rs.rows.first; - BUG dart, first is null:
            Map map = rs.rows[0];
            int newVersion = map['value'];
            if (database.onVersionChangeCtlr != null) {

              database.onVersionChangeCtlr.add(new _WebSqlVersionChangeEvent(database, database.version, newVersion, transaction));
            }
            return new Future.error(new StateError("database upgraded from ${database.version} to $newVersion"));
          }
          var sqlSelect = "SELECT key_path, auto_increment, indecies FROM stores WHERE name = ?";
          var sqlArgs = [name];
          return execute(sqlSelect, sqlArgs).then((SqlResultSet rs) {
            if (rs.rows.length == 0) {
              return new Future.error("store $name not found");
            }
            Map row = rs.rows[0];
            String keyPath = row['key_path'];
            bool autoIncrement = row['auto_increment'] > 0;

            _initOptions(keyPath, autoIncrement);

            String indeciesText = row['indecies'];

            // merge lazy loaded data
            Map indeciesData = _WebSqlIndex.indeciesDataFromString(indeciesText);
            indeciesData.forEach((name, data) {
              _WebSqlIndex index = indecies[name];
              if (index == null) {
                // create
                index = new _WebSqlIndex(this, name, data);
                indecies[name] = index;
              } else {
                // merge
                index.data = data;
              }
            });
            return computation();

            //          if (keyPath == null && !autoIncrement) {
            //            throw new ArgumentError("neither keyPath nor autoIncrement set");
            //          }

          });
        });
        return _lazyPrepare;
      } else {
        return _lazyPrepare.then((_) {
          return computation();
        });
      }
    }
    return computation();
  }

  //  /**
  //   * keyPath might not be valid before
  //   */
  //  @deprecated
  //  Future<WebSqlTransaction> _checkStoreOld() {
  //
  //    // this is also an indicator
  //    if (!ready) {
  //      // Make sure the db was not upgrade
  //      // TODO do this at the beginning of each transaction
  //      var sqlSelect = "SELECT value FROM version WHERE value > ?";
  //      var sqlArgs = [database.version];
  //      return execute(sqlSelect, sqlArgs).then((SqlResultSet rs) {
  //        if (rs.rows.length > 0) {
  //          // Send an onVersionChange event
  //          //Map map = rs.rows.first; - BUG dart, first is null:
  //          Map map = rs.rows[0];
  //          int newVersion = map['value'];
  //          if (database.onVersionChangeCtlr != null) {
  //
  //            database.onVersionChangeCtlr.add(new _WebSqlVersionChangeEvent(database, database.version, newVersion, transaction));
  //          }
  //          return new Future.error(new StateError("database upgraded from ${database.version} to $newVersion"));
  //        }
  //        print("A");
  //        var sqlSelect = "SELECT key_path, auto_increment, indecies FROM stores WHERE name = ?";
  //        var sqlArgs = [name];
  //        return execute(sqlSelect, sqlArgs).then((SqlResultSet rs) {
  //          if (rs.rows.length == 0) {
  //            return new Future.error("store $name not found");
  //          }
  //          Map row = rs.rows[0];
  //          String keyPath = row['key_path'];
  //          bool autoIncrement = row['auto_increment'] > 0;
  //
  //          _initOptions(keyPath, autoIncrement);
  //
  //          String indeciesText = row['indecies'];
  //
  //          // merge lazy loaded data
  //          Map indeciesData = WebSqlIndex.indeciesDataFromString(indeciesText);
  //          indeciesData.forEach((name, data) {
  //            WebSqlIndex index = indecies[name];
  //            if (index == null) {
  //              // create
  //              index = new WebSqlIndex(this, name, data);
  //              indecies[name] = index;
  //            } else {
  //              // merge
  //              index.data = data;
  //            }
  //          });
  //          return transaction;
  //
  //          //          if (keyPath == null && !autoIncrement) {
  //          //            throw new ArgumentError("neither keyPath nor autoIncrement set");
  //          //          }
  //
  //        });
  //      });
  //    }
  //    return new Future.value(transaction);
  //  }

  Future _add(dynamic value, dynamic key) {
    String columns = VALUE_COLUMN_NAME;
    String values = '?';
    List args = [encodeValue(value)];
    if (key != null) {
      columns = keyColumn + ", " + columns;
      values = "?, " + values;
      args.insert(0, key);
    }
    // Add the index value for each index
    indecies.values.forEach((_WebSqlIndex index) {
      columns += ", " + index.keyColumn;
      values += ", ?";
      args.add(encodeKey(value[index.keyPath]));
    });

    var sqlInsert = "INSERT INTO $sqlTableName ($columns) VALUES ($values)";
    return execute(sqlInsert, args).then((SqlResultSet rs) {
      if (key != null) {
        return key;
      }
      return rs.insertId;
    });
  }
  @override
  Future add(dynamic value, [dynamic key]) {

    return _checkWritableStore(() {
      if (key == null) {
        if (keyPath != null) {
          key = value[keyPath];
        }
      } else {
        if (!checkKeyValue(keyPath, key, value)) {
          return new Future.error(new ArgumentError("both key $key and inline keyPath ${value[keyPath]}"));
        }
      }

      return _add(value, key);
    });
  }

  Future _put(dynamic value, [dynamic key]) {
    if (!checkKeyValue(keyPath, key, value)) {
      return new Future.error(new ArgumentError("both key $key and inline keyPath ${value[keyPath]}"));
    }

    String sets = "$VALUE_COLUMN_NAME = ?";
    String values = '?';
    List args = [encodeValue(value)];

    // Add the index value for each index
    indecies.values.forEach((_WebSqlIndex index) {
      sets += ", ${index.keyColumn} = ?";
      args.add(encodeKey(value[index.keyPath]));
    });

    // Add key arg
    args.add(encodeKey(key));

    var sqlUpdate = "UPDATE $sqlTableName SET $sets WHERE $keyColumn = ?";
    return execute(sqlUpdate, args).then((SqlResultSet rs) {
      // If not updated try to add it instead
      if (rs.rowsAffected == 0) {
        return _add(value, key);
      }
      return key;
    });
  }

  @override
  Future put(dynamic value, [dynamic key]) {
    if (key == null) {
      return add(value);
    }

    return _checkWritableStore(() {
      return _put(value, key);
    });
  }

  Future _get(dynamic key, [String keyPath]) {

    var sqlSelect = "SELECT $VALUE_COLUMN_NAME FROM $sqlTableName WHERE ${sqlColumnName(keyPath)} = ? LIMIT 1";
    var sqlArgs = [encodeKey(key)];
    return execute(sqlSelect, sqlArgs).then((SqlResultSet rs) {
      if (rs.rows.length == 0) {
        return null;
      }
      var value = decodeValue(rs.rows[0][VALUE_COLUMN_NAME]);

      // Add key?
      if (keyPath != null) {
        value[keyPath] = key;
      }
      return value;
    });
  }

  Future _getKey(dynamic key, [String keyPath]) {
    var sqlSelect = "SELECT $keyColumn FROM $sqlTableName WHERE ${sqlColumnName(keyPath)} = ? LIMIT 1";
    var sqlArgs = [encodeKey(key)];
    return execute(sqlSelect, sqlArgs).then((SqlResultSet rs) {
      if (rs.rows.length == 0) {
        return null;
      }
      var primaryKey = decodeKey(rs.rows[0][keyColumn]);
      return primaryKey;
    });
  }

  @override
  Future getObject(dynamic key) {

    //return _checkStore().then((_) {
    return _checkStore(() {
      return _get(key, keyPath);
    });
  }

  @override
  Future clear() {
    return _checkWritableStore(() {
      var sqlClear = "DELETE FROM $sqlTableName";
      return execute(sqlClear, []).then((SqlResultSet rs) {
      });
    });
  }

  @override
  Future delete(key) {
    return _checkWritableStore(() {
      return _delete(key);
    });
  }

  Future _delete(key) {
    var sqlDelete = "DELETE FROM $sqlTableName WHERE key = ?";
    var sqlArgs = [encodeKey(key)];
    return execute(sqlDelete, sqlArgs).then((_) {
      // delete returns a Future with a null value
      return null;
    });
  }

  @override
  Index index(String name) {
    Index index = indecies[name];
    if (index == null) {
      // lazy loaded already?
      if (ready) {
        throw new ArgumentError("index $name not found");
      }
      index = new _WebSqlIndex(this, name, null);

      // cache it
      indecies[name] = index;

      //
      // throw new ArgumentError("index $name not found");
    }


    // loader later when used
    return index;
  }

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    _WebSqlIndex index = new _WebSqlIndex(this, name, new _WebSqlIndexData(keyPath, unique, multiEntry));
    indecies[name] = index;

    // let it for later
    database.onVersionChangeCreatedIndexes.add(index);

    return index;
  }

  @override
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {

    _WebSqlCursorWithValueController ctlr = new _WebSqlCursorWithValueController(this, direction, autoAdvance);

    // Future
    _checkStore(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }

  @override
  Future<int> count([key_OR_range]) {
    return _checkStore(() {
      _CountQuery query = new _CountQuery(sqlTableName, keyColumn, key_OR_range);
      return query.count(transaction);
    });
  }
}
