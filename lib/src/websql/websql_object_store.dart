part of idb_shim_websql;

// meta data is loaded only once

class OBSOLETE_WebSqlObjectStoreMeta extends IdbObjectStoreMeta {
  static const String valueColumnName = 'value';
  static const String keyDefaultColumnName = 'key';

  OBSOLETE_WebSqlObjectStoreMeta(
      String name, String keyPath, bool autoIncrement)
      : super(name, keyPath, autoIncrement) {
    autoIncrement = (autoIncrement == true);
  }

  String sqlColumnName(String keyPath) {
    if (keyPath == null) {
      return keyDefaultColumnName;
    } else {
      return "_col_$keyPath";
    }
  }

  /**
   * indecies <=> String
   */
  /*
  Map<String, IdbIndexMeta> indeciesDataFromString(String indeciesText) {
    Map indeciesData = new Map();

    if (indeciesText != null) {
      List indexList = JSON.decode(indeciesText);
      indexList.forEach((Map indexDef) {
        String name = indexDef['name'];
        String keyPath = indexDef['key_path'];
        bool multiEntry = indexDef['multi_entry'];
        bool unique = indexDef['unique'];
        indeciesData[name] =
            new IdbIndexMeta(name, keyPath, unique, multiEntry);
      });
    }
    return indeciesData;
  }
  */
}

class _WebSqlObjectStore extends ObjectStore with ObjectStoreWithMetaMixin {
  static const String VALUE_COLUMN_NAME = 'value';
  static const String KEY_DEFAULT_COLUMN_NAME = 'key';

  _WebSqlTransaction transaction;

  @override
  final IdbObjectStoreMeta meta;

  _WebSqlDatabase get database => transaction.database as _WebSqlDatabase;

  bool get ready => keyColumn != null;
  Future _lazyPrepare;

  _WebSqlObjectStore(this.transaction, this.meta);

  String sqlColumnName(String keyPath) {
    if (keyPath == null) {
      return KEY_DEFAULT_COLUMN_NAME;
    } else {
      return "_col_$keyPath";
    }
  }

  // If null this means we need to load from database
  String _keyColumn;
  String get keyColumn {
    if (_keyColumn == null) {
      _keyColumn = sqlColumnName(keyPath);
    }
    return _keyColumn;
  }

  String get sqlTableName {
    return getSqlTableName(name);
  }

  String getSqlIndexName(String keyPath) {
    return "_index_${name}_${keyPath}";
  }

  static String getSqlTableName(String storeName) {
    return "_store_$storeName";
  }

  Future<SqlResultSet> execute(String statement, [List args]) {
    return transaction.execute(statement, args);
  }

  Future _deleteTable(_WebSqlTransaction transaction) {
    String dropSql = "DROP TABLE IF EXISTS $sqlTableName";
    return transaction.execute(dropSql);
  }

  // update meta information in sql
  Future update() async {
    String updateSql = "UPDATE stores SET meta = ? WHERE name = ?";

    String metaText = json.encode(meta.toMap());
    List updateArgs = [metaText, name];
    await transaction.execute(updateSql, updateArgs);
  }

  // create
  Future create() {
    String createSql = "CREATE TABLE $sqlTableName (${keyColumn} " +
        (autoIncrement
            ? "INTEGER PRIMARY KEY AUTOINCREMENT"
            : "BLOB PRIMARY KEY") +
        ", $VALUE_COLUMN_NAME BLOB)";
    String insertStore = "INSERT INTO stores (name, meta) VALUES (?, ?)";
    String metaText = json.encode(meta.toMap());
    List insertStoreArgs = [name, metaText];

    return _deleteTable(transaction).then((_) {
      return transaction.execute(createSql);
    }).then((_) {
      return transaction.execute(insertStore, insertStoreArgs);
    });
  }

  Future _checkWritableStore(Future computation()) {
    if (transaction._meta.mode != idbModeReadWrite) {
      return new Future.error(new DatabaseReadOnlyError());
    }
    return _checkStore(computation);
  }

  _WebSqlIndex _getIndex(String name) {
    IdbIndexMeta indexMeta = meta.index(name);
    if (indexMeta != null) {
      return new _WebSqlIndex(this, indexMeta);
    }
    return null;
  }

  // Don't make it async as it must run before completed is called
  Future<T> _checkStore<T>(FutureOr<T> computation()) {
    // this is also an indicator
    //if (!ready) {
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
            database.onVersionChangeCtlr.add(new _WebSqlVersionChangeEvent(
                database, database.version, newVersion, transaction));
          }
          return new Future.error(new StateError(
              "database upgraded from ${database.version} to $newVersion"));
        }
      });
    }
    return _lazyPrepare.then((_) {
      return computation();
    });
  }

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
    for (IdbIndexMeta indexMeta in meta.indecies) {
      columns += ", " + sqlColumnName(indexMeta.keyPath);
      values += ", ?";
      args.add(encodeKey(value[indexMeta.keyPath]));
    }

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
        if (!checkKeyValueParam(keyPath, key, value)) {
          return new Future.error(new ArgumentError(
              "both key $key and inline keyPath ${value[keyPath]}"));
        }
      }
      if ((key == null) && (!autoIncrement)) {
        throw new _IdbWebSqlError(_IdbWebSqlError.MISSING_KEY,
            "neither keyPath nor autoIncrement set and trying to add object without key");
      }

      return _add(value, key);
    });
  }

  Future _put(dynamic value, [dynamic key]) {
    if (!checkKeyValueParam(keyPath, key, value)) {
      return new Future.error(new ArgumentError(
          "both key $key and inline keyPath ${value[keyPath]}"));
    }

    if (key == null) {
      if (keyPath != null) {
        key = value[keyPath];
      }
    }

    if ((key == null) && (!autoIncrement)) {
      throw new _IdbWebSqlError(_IdbWebSqlError.MISSING_KEY,
          "neither keyPath nor autoIncrement set and trying to add object without key");
    }

    String sets = "$VALUE_COLUMN_NAME = ?";
    //String values = '?';
    List args = [encodeValue(value)];

    // Add the index value for each index
    for (IdbIndexMeta indexMeta in meta.indecies) {
      sets += ", ${sqlColumnName(indexMeta.keyPath)} = ?";
      args.add(encodeKey(value[indexMeta.keyPath]));
    }

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
    return _checkWritableStore(() {
      return _put(value, key);
    });
  }

  Future _get(dynamic key, [String keyPath]) {
    var sqlSelect =
        "SELECT $VALUE_COLUMN_NAME FROM $sqlTableName WHERE ${sqlColumnName(keyPath)} = ? LIMIT 1";
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
    var sqlSelect =
        "SELECT $keyColumn FROM $sqlTableName WHERE ${sqlColumnName(keyPath)} = ? LIMIT 1";
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
    checkKeyParam(key);
    return _checkStore(() {
      return _get(key, keyPath);
    });
  }

  @override
  Future clear() {
    return _checkWritableStore(() {
      var sqlClear = "DELETE FROM $sqlTableName";
      return execute(sqlClear, []).then((SqlResultSet rs) {});
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
    //devWarning;
    return _getIndex(name);
  }

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    IdbIndexMeta indexMeta =
        new IdbIndexMeta(name, keyPath as String, unique, multiEntry);
    meta.createIndex(database.meta, indexMeta);
    _WebSqlIndex index = new _WebSqlIndex(this, indexMeta);
    // let it for later
    return index;
  }

  @override
  void deleteIndex(String name) {
    meta.deleteIndex(database.meta, name);
  }

  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    _WebSqlCursorWithValueController ctlr =
        new _WebSqlCursorWithValueController(this, direction, autoAdvance);

    // Future
    _checkStore(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }

  @override
  Future<int> count([key_OR_range]) {
    return _checkStore(() {
      _CountQuery query =
          new _CountQuery(sqlTableName, keyColumn, key_OR_range);
      return query.count(transaction);
    });
  }
}
