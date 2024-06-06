library;

import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  defineAllTests(idbMemoryContext);
  // running twice, should not just as super fast
  defineAllTests(idbMemoryContext);
}
