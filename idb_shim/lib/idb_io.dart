library idb_shim.io;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_io.dart';

export 'package:idb_shim/src/io/io_compat.dart';

export 'idb_client_sembast.dart' show idbFactorySembastMemory;

/// Get an io base factory from the defined root path
IdbFactory getIdbFactorySembastIo(String path) =>
    IdbFactorySembast(databaseFactoryIo, path);

///
/// Only sembast io is persistent
///
IdbFactory getIdbFactoryPersistent(String path) {
  return getIdbFactorySembastIo(path);
}
