library idb_shim.idb_io_test_common;

import 'idb_test_common.dart';
export 'idb_test_common.dart';
import 'package:sembast/sembast_io.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:path/path.dart';

class IoTestContext extends SembastFsTestContext {
  IoTestContext() {
    factory = new IdbFactorySembast(databaseFactoryIo, testOutTopPath);
  }
}

String projectRoot = '.';
String get testOutTopPath =>
    join(projectRoot, '.dart_tool', 'idb_shim', 'test');
