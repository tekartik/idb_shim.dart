/// Sembast based implementation.
library;

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/sembast/sembast_factory.dart';
import 'package:sembast/sembast.dart' as sdb;
export 'idb_shim.dart';

/// Sembast factory name.
const idbFactoryNameSembast = 'sembast';

/// Sembast memory based factory
IdbFactory get idbFactorySembastMemory => idbFactorySembastMemoryImpl;

/// IndexedDB factory on top of sembast
abstract class IdbFactorySembast extends IdbFactoryBase {
  /// Create a sembast-based factory on a given top path.
  ///
  /// If [path] is null, path are relative to the root.
  factory IdbFactorySembast(
    sdb.DatabaseFactory databaseFactory, [
    String? path,
  ]) => IdbFactorySembastImpl(databaseFactory, path);

  /// The underlying sembast factory (compat)
  sdb.DatabaseFactory get sdbFactory;

  /// The underlying factory.
  sdb.DatabaseFactory get sembastFactory;

  /// Get the underlying sembast database for a given database (compat)
  sdb.Database? getSdbDatabase(Database db);

  /// Get the underlying sembast database for a given database
  sdb.Database? getSembastDatabase(Database db);

  /// Create a database from an existing sembast database. (compat)
  Future<Database> openFromSdbDatabase(sdb.Database sdbDb);

  /// Create a database from an existing sembast database.
  Future<Database> openFromSembastDatabase(sdb.Database sdbDb);

  /// The path of a named Sembast database.
  String getDbPath(String dbName);
}
