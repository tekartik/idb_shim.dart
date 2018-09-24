library idb_shim_sembast;

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/sembast/sembast_factory.dart';
import 'package:sembast/sembast.dart' as sdb;

const idbFactoryNameSembast = "sembast";

abstract class IdbFactorySembast extends IdbFactoryBase {
  factory IdbFactorySembast(sdb.DatabaseFactory databaseFactory,
          [String path]) =>
      IdbFactorySembastImpl(databaseFactory, path);

  // The underlying factory
  sdb.DatabaseFactory get sdbFactory;

  // get the underlying sembast database for a given database
  sdb.Database getSdbDatabase(Database db);

  Future<Database> openFromSdbDatabase(sdb.Database sdbDb);

  // The path of a named _SdbDatabase
  String getDbPath(String dbName);
}
