/// The Dart VM (io) factories, storing each database in a sembast file.
///
/// [idbFactorySembastIo] takes database names as paths relative to the
/// current directory, [getIdbFactorySembastIo] roots them below a path.
/// For a single process only (tools, tests); on Flutter mobile and desktop
/// prefer `package:idb_sqflite`. Imports `dart:io`: not for web code.
library;

import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast_io.dart';

/// @nodoc
export 'idb_client_sembast.dart'
    show
        /// @nodoc
        idbFactorySembastMemory;
export 'idb_shim.dart';

IdbFactory? _idbFactorySembastIo;

/// An io based factory based on sembast.
IdbFactory get idbFactorySembastIo =>
    _idbFactorySembastIo ??= IdbFactorySembast(databaseFactoryIo);

/// Get an io base factory from the defined root path
IdbFactory getIdbFactorySembastIo(String path) =>
    IdbFactorySembast(databaseFactoryIo, path);

/// Only sembast io is persistent
IdbFactory getIdbFactoryPersistent(String path) {
  return getIdbFactorySembastIo(path);
}
