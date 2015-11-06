library idb_shim.idb_io_test_common;

import 'idb_test_common.dart';
export 'idb_test_common.dart';
import 'dart:mirrors';
import 'package:sembast/sembast_io.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:path/path.dart';

class IoTestContext extends SembastFsTestContext {
  IoTestContext() {
    factory = new IdbSembastFactory(ioDatabaseFactory, testOutTopPath);
  }
}

class _TestUtils {
  static final String scriptPath =
      (reflectClass(_TestUtils).owner as LibraryMirror).uri.toFilePath();
}

String get testScriptPath => _TestUtils.scriptPath;
String get testOutTopPath => join(dirname(dirname(testScriptPath)), "test_out");
