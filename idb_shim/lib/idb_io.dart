library idb_shim.io;

import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_io.dart';

export 'idb_client_sembast.dart' show idbFactorySembastMemory;
export 'idb_shim.dart';

IdbFactory? _idbFactorySembastIo;

/// An io based factory based on sembast.
IdbFactory get idbFactorySembastIo =>
    _idbFactorySembastIo ??= IdbFactorySembast(databaseFactoryIo);

/// Get an io base factory from the defined root path
IdbFactory getIdbFactorySembastIo(String path) =>
    IdbFactorySembast(databaseFactoryIo, path);

///
/// Only sembast io is persistent
///
IdbFactory getIdbFactoryPersistent(String path) {
  return getIdbFactorySembastIo(path);
}
