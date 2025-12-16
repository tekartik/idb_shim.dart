library;

import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/sembast.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  disableSembastCooperator();
  defineAllTests(idbMemoryContext);
}
