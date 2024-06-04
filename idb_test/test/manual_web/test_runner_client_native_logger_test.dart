@TestOn('browser')
library idb_shim.test_runner_client_native_test;

import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:test/test.dart';

import '../web/test_runner_client_native_test_common.dart';

void main() {
  idbNativeFactoryTests(getIdbFactoryLogger(idbFactoryNative));
}
