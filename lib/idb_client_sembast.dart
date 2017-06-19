library idb_shim_sembast;

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart' as sdb;

import 'src/common/common_validation.dart';
import 'src/common/common_value.dart';

part 'src/sembast/sembast_cursor.dart';

part 'src/sembast/sembast_database.dart';
part 'src/sembast/sembast_factory.dart';

part 'src/sembast/sembast_index.dart';

part 'src/sembast/sembast_object_store.dart';

part 'src/sembast/sembast_transaction.dart';
//import 'package:tekartik_core/dev_utils.dart';

const idbFactoryNameSembast = "sembast";

abstract class IdbSembastFactory extends IdbFactory {
  factory IdbSembastFactory(sdb.DatabaseFactory databaseFactory,
          [String path]) =>
      new _IdbSembastFactory(databaseFactory, path);

  IdbSembastFactory._();

  // The underlying factory
  sdb.DatabaseFactory get sdbFactory;

  // get the underlying sembast database for a given database
  sdb.Database getSdbDatabase(Database db);

  Future<Database> openFromSdbDatabase(sdb.Database sdbDb);

  // The path of a named _SdbDatabase
  String getDbPath(String dbName);

  // common implementation
  int cmp(Object first, Object second) => compareKeys(first, second);
}
