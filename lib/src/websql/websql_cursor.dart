part of idb_websql;

abstract class _WebSqlCommonCursor<T extends Cursor> {
  Map _map;
  _WebSqlCursorBaseController<T> _ctlr;

  String get _primaryKeyColumn => _ctlr.primaryKeyColumn;
  String get _keyColumn => _ctlr.keyColumn;

  Object get key => decodeKey(_map[_keyColumn]);

  Object get primaryKey => decodeKey(_map[_primaryKeyColumn]);

  String get direction => _ctlr.direction;

  void advance(int count) {
    // Needed to dart2js
    // ugly but better than playing multiple time the same big query
    _ctlr.store.transaction._sqlTransaction.ping().then((_) {
      _ctlr.advance(count);
    });

  }

  void next([Object key]) {
    if (key != null) {
      throw new UnimplementedError();
    }
    advance(1);
  }

  Future update(value) {
    // Calling direct method needed for dart2js
    return _ctlr.store._put(value, primaryKey);
  }

  Future delete() {
    // Calling direct method needed for dart2js
    return _ctlr.store._delete(primaryKey);
  }
}

class _WebSqlCursor extends Cursor with _WebSqlCommonCursor<Cursor> {
  _WebSqlCursor(_WebSqlKeyCursorBaseController ctlr, Map map) {
    this._map = map;
    this._ctlr = ctlr;
  }
}

/**
 * 
 */
class _WebSqlCursorWithValue extends CursorWithValue with _WebSqlCommonCursor<CursorWithValue> {

  _WebSqlCursorWithValue(_WebSqlCursorWithValueBaseController ctlr, Map map) {
    this._map = map;
    this._ctlr = ctlr;
  }

  @override
  Object get value => decodeValue(_map[_WebSqlObjectStore.VALUE_COLUMN_NAME]);
}

abstract class _WebSqlCursorBaseController<T extends Cursor> {
  SqlResultSet _sqlResultSet;

  String direction;
  bool autoAdvance;

  int currentIndex;
  SqlResultSetRowList rows;

  _WebSqlTransaction get transaction => store.transaction;

  _WebSqlObjectStore get store;
  String get primaryKeyColumn => store.keyColumn;
  String get keyColumn;

  T get newCursor;

  // should be one or 0
  int _operationCount = 0;
  //
  //  void beginOperation() {
  //    _operationCount++;
  //    transaction._beginOperation();
  //  }
  //
  //  bool endOperation() {
  //    if (_operationCount > 0) {
  //      --_operationCount;
  //      transaction._endOperation();
  //      return true;
  //    }
  //    return false;
  //  }

  _WebSqlCursorBaseController(this.direction, this.autoAdvance) {
    if (direction == null) {
      direction = DIRECTION_NEXT;
    }
    if (autoAdvance == null) {
      autoAdvance = true;
    }

  }

  // Sync must be true
  StreamController<T> _ctlr = new StreamController(sync: true);

  bool get currentIndexValid {
    int length = rows.length;

    return (currentIndex >= 0) && (currentIndex < length);
  }

  /**
   * false if it faield
   */
  bool advance(int count) {
    int length = rows.length;
    currentIndex += count;
    if (!currentIndexValid) {
      // Prevent auto advance
      autoAdvance = false;
      // endOperation();
      // pure async

      _ctlr.close();
      return false;
    } else {
      _ctlr.add(newCursor);
      // return new Future.value();
      return true;

    }
  }

  void _autoNext() {
    if (advance(1)) {
      if (autoAdvance) {
        _autoNext();
      }
    }
  }

  Stream<T> get stream => _ctlr.stream;

  /**
   * Set the result from query, this will trigger the controller
   */
  void set sqlResultSet(SqlResultSet sqlResultSet) {
    currentIndex = -1;
    rows = sqlResultSet.rows;
    //    if (sqlResultSet.rows.first;
    //    sqlResultSet.rows.
    //    if (rows.length == 0) {
    //      _ctlr.close();
    //    } else {
    //      _ctlr.add(new WebSqlCursorWithValue(this, row));
    //    }
    //beginOperation();
    _autoNext();
  }
}

abstract class _WebSqlKeyCursorBaseController extends _WebSqlCursorBaseController<Cursor> {
  _WebSqlKeyCursorBaseController(String direction, bool autoAdvance): super(direction, autoAdvance);

  Cursor get newCursor => new _WebSqlCursor(this, rows[currentIndex]);
}

abstract class _WebSqlCursorWithValueBaseController extends _WebSqlCursorBaseController<CursorWithValue> {
  _WebSqlCursorWithValueBaseController(String direction, bool autoAdvance): super(direction, autoAdvance);

  Cursor get newCursor => new _WebSqlCursorWithValue(this, rows[currentIndex]);
}

class _WebSqlCursorWithValueController extends _WebSqlCursorWithValueBaseController with _WebSqlCursorCommonController, _WebSqlCursorWithValueCommonController {

  _WebSqlObjectStore store;
  String get keyColumn => primaryKeyColumn;

  _WebSqlCursorWithValueController(this.store, String direction, bool autoAdvance) //
      : super(direction, autoAdvance) {
  }
}

abstract class _WebSqlCursorWithValueCommonController {

  String get baseSelectedColumns;

  String get selectedColumns {
    return "$baseSelectedColumns, ${_WebSqlObjectStore.VALUE_COLUMN_NAME}";
  }
}
abstract class _WebSqlCursorCommonController {
  String get direction;
  _WebSqlTransaction get transaction;
  void set sqlResultSet(SqlResultSet sqlResultSet);
  // to override
  String get selectedColumns => baseSelectedColumns;

  String get primaryKeyColumn;

  String get baseSelectedColumns {
    String selected = primaryKeyColumn;
    if (keyColumn != primaryKeyColumn) {
      selected += ", $keyColumn";
    }
    return selected;
  }
  _WebSqlObjectStore get store;
  String get sqlTableName => store.sqlTableName;
  String get keyColumn;

  Future execute(key, CommonKeyRange keyRange) {
    String ORDER;
    //    if (key != null) {
    //      return new Future.error(new UnimplementedError("cursor by key not supported"));
    //    }
    //    if (keyRange != null) {
    //      return new Future.error(new UnimplementedError("cursor by range not supported"));
    //    }

    switch (direction) {
      case DIRECTION_NEXT:
        ORDER = "ASC";
        break;
      case DIRECTION_PREV:
        ORDER = "DESC";
        break;
      default:
        throw new ArgumentError("direction '$direction' not supported");
    }
    List args = [];
    var sqlSelect = "SELECT $selectedColumns FROM $sqlTableName";
    if (keyRange != null) {
      sqlSelect += " WHERE 1=1";
      if (keyRange.lower != null) {
        if (keyRange.lowerOpen == true) {
          sqlSelect += " AND $keyColumn > ?";
        } else {
          sqlSelect += " AND $keyColumn >= ?";
        }
        args.add(keyRange.lower);
      }
      if (keyRange.upper != null) {
        if (keyRange.upperOpen == true) {
          sqlSelect += " AND $keyColumn < ?";
        } else {
          sqlSelect += " AND $keyColumn <= ?";
        }
        args.add(keyRange.upper);
      }
    }
    if (key != null) {
      if (keyRange == null) {
        sqlSelect += " WHERE ";
      } else {
        sqlSelect += " AND ";
      }
      sqlSelect += "$keyColumn = ?";

      args.add(key);
    }
    sqlSelect += " ORDER BY $keyColumn " + ORDER;
    //var sqlArgs = [encodeKey(key)];
    return transaction.execute(sqlSelect, args).then((SqlResultSet rs) {
      sqlResultSet = rs;
      // return ctlr.
    });

  }
}
abstract class _WebSqlIndexCursorCommonController {
  _WebSqlIndex index;

  _WebSqlObjectStore get store => index.store;

  String get keyColumn => index.keyColumn;
}

class _WebSqlKeyIndexCursorController extends _WebSqlKeyCursorBaseController with _WebSqlIndexCursorCommonController, _WebSqlCursorCommonController {
  _WebSqlKeyIndexCursorController(_WebSqlIndex index, String direction, bool autoAdvance) //
      : super(direction, autoAdvance) {
    this.index = index;
  }
}

class _WebSqlIndexCursorWithValueController extends _WebSqlCursorWithValueBaseController with _WebSqlIndexCursorCommonController, _WebSqlCursorCommonController, _WebSqlCursorWithValueCommonController {
  _WebSqlIndexCursorWithValueController(_WebSqlIndex index, String direction, bool autoAdvance) //
      : super(direction, autoAdvance) {
    this.index = index;
  }
}
