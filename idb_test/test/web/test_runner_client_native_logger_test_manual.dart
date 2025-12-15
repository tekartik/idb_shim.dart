@TestOn('browser')
library;

import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_test/idb_test_common.dart';

import 'test_runner_client_native_test_common.dart';

void main() {
  idbNativeFactoryTests(getIdbFactoryLogger(idbFactoryNative));
}
