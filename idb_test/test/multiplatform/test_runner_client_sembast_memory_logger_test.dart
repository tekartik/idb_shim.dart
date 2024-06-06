library;

import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  IdbFactoryLogger.debugMaxLogCount = 50;
  var context = SembastMemoryTestContext();
  context.wrapInLogger();
  defineAllTests(context);
}
