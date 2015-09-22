part of idb_shim_websql;

class _Query {
  String sqlStatement;
  List<Object> arguments;
}

const String _SQL_COUNT_COLUMN = "_COUNT";
const _SQL_COUNT = "COUNT(*) AS $_SQL_COUNT_COLUMN";

class _SelectQuery extends _Query {
  String _selectedColumns;
  String _sqlTableName;
  var _key_OR_range;
  String _direction;
  String _keyColumn;

  _SelectQuery(
      this._selectedColumns,
      this._sqlTableName,
      this._keyColumn, //
      this._key_OR_range,
      this._direction);

  Future<SqlResultSet> execute(_WebSqlTransaction transaction) {
    String order;
    //    if (key != null) {
    //      return new Future.error(new UnimplementedError("cursor by key not supported"));
    //    }
    //    if (keyRange != null) {
    //      return new Future.error(new UnimplementedError("cursor by range not supported"));
    //    }

    if (_direction != null) {
      switch (_direction) {
        case idbDirectionNext:
          order = "ASC";
          break;
        case idbDirectionPrev:
          order = "DESC";
          break;

        default:
          throw new ArgumentError("direction '$_direction' not supported");
      }
    }
    List args = [];
    var sqlSelect = "SELECT $_selectedColumns FROM $_sqlTableName";
    if (_key_OR_range is KeyRange) {
      KeyRange keyRange = _key_OR_range;
      sqlSelect += " WHERE 1=1";
      if (keyRange.lower != null) {
        if (keyRange.lowerOpen == true) {
          sqlSelect += " AND $_keyColumn > ?";
        } else {
          sqlSelect += " AND $_keyColumn >= ?";
        }
        args.add(keyRange.lower);
      }
      if (keyRange.upper != null) {
        if (keyRange.upperOpen == true) {
          sqlSelect += " AND $_keyColumn < ?";
        } else {
          sqlSelect += " AND $_keyColumn <= ?";
        }
        args.add(keyRange.upper);
      }
    } else if (_key_OR_range != null) {
      var key = _key_OR_range;
      sqlSelect += " WHERE $_keyColumn = ?";
      args.add(key);
    } else {
      sqlSelect += " WHERE $_keyColumn NOT NULL";
    }

    // order not needed for COUNT(*)
    if (order != null) {
      sqlSelect += " ORDER BY $_keyColumn " + order;
    }
    //var sqlArgs = [encodeKey(key)];
    return transaction.execute(sqlSelect, args);
  }
}

class _CountQuery extends _SelectQuery {
  _CountQuery(String sqlTableName, String keyColumn, key_OR_range) //
      : super(_SQL_COUNT, sqlTableName, keyColumn, key_OR_range, null);

  Future<int> count(_WebSqlTransaction transaction) {
    return execute(transaction).then((SqlResultSet rs) {
      if (rs.rows.length == 0) {
        return null;
      }
      return (rs.rows[0][_SQL_COUNT_COLUMN]);
    });
  }
}
