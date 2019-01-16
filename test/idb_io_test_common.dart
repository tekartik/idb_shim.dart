library idb_shim.idb_io_test_common;

import 'package:idb_shim/idb_client_sembast.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';

import 'idb_test_common.dart';

export 'idb_test_common.dart';

class IoTestContext extends SembastFsTestContext {
  IoTestContext() {
    factory = IdbFactorySembast(databaseFactoryIo, testOutTopPath);
  }
}

String projectRoot = '.';

String get testOutTopPath =>
    join(projectRoot, '.dart_tool', 'idb_shim', 'test');
