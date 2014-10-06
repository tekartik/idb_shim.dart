library idb_websql;

import 'idb_client.dart';
import 'dart:async';
import 'dart:convert';

// import 'dart:web_sql' as wql;
import 'package:idb_shim/src/websql/websql_wrapper.dart';
import 'package:idb_shim/src/websql/websql_client_constants.dart';
import 'package:idb_shim/src/common/common_value.dart';
//import 'package:idb_shim/src/utils/dev_utils.dart';
import "src/utils/core_imports.dart";

part 'src/websql/websql_database.dart';
part 'src/websql/websql_transaction.dart';
part 'src/websql/websql_object_store.dart';
part 'src/websql/websql_global_store.dart';
part 'src/websql/websql_utils.dart';
part 'src/websql/websql_index.dart';
part 'src/websql/websql_cursor.dart';
part 'src/websql/websql_query.dart';
part 'src/websql/websql_error.dart';

class IdbWebSqlFactory extends IdbFactory {

  // global store
  _WebSqlGlobalStore _globalStore = new _WebSqlGlobalStore();

  static IdbWebSqlFactory _instance;
  IdbWebSqlFactory._();

  String get name => IDB_FACTORY_WEBSQL;
  
  factory IdbWebSqlFactory() {
    if (_instance == null) {
      _instance = new IdbWebSqlFactory._();
    }
    return _instance;

  }

  @override
  Future<Database> open(String dbName, {int version, OnUpgradeNeededFunction onUpgradeNeeded, OnBlockedFunction onBlocked}) {

    // check params
    if ((version == null) != (onUpgradeNeeded == null)) {
      return new Future.error(new ArgumentError('version and onUpgradeNeeded must be specified together'));
    }
    if (version == 0) {
      return new Future.error(new ArgumentError('version cannot be 0'));
    } else if (version == null) {
      version = 1;
    }

    if (dbName == null) {
      return new Future.error(new ArgumentError('dbName cannot be null'));
    }

    // add the db name and remove it if it fails
    return _globalStore.addDatabaseName(dbName).then((_) {
      _WebSqlDatabase database = new _WebSqlDatabase(this, dbName);
      return database.open(version, onUpgradeNeeded).then((_) {
        return database;
      }, onError: (e) {
        _globalStore.deleteDatabaseName(dbName);
        throw e;
      });
    });
  }


  @override
  Future<IdbFactory> deleteDatabase(String dbName, {OnBlockedFunction onBlocked}) {
    if (dbName == null) {
      return new Future.error(new ArgumentError('dbName cannot be null'));
    }
    // remove the db name and add it back if it fails
    return _globalStore.deleteDatabaseName(dbName).then((_) {
      _WebSqlDatabase database = new _WebSqlDatabase(this, dbName);
      return database._delete().then((_) {
        return this;
      }, onError: (e) {
        _globalStore.addDatabaseName(dbName);
        throw e;
      });
    });
  }

  @override
  bool get supportsDatabaseNames {
    return true;
  }

  @override
  Future<List<String>> getDatabaseNames() {
    return _globalStore.getDatabaseNames();
  }

  /**
   * Check if WebSQL is supported on this platform
   */
  static bool get supported {
    return SqlDatabase.supported;
  }
}
