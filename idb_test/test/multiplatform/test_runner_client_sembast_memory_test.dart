@TestOn('!wasm')
library;

import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  defineAllTests(idbMemoryContext);
  defineAllTests(idbMemoryContext);
}
