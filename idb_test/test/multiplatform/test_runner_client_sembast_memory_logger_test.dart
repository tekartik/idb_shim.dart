import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  var context = SembastMemoryTestContext();
  context.wrapInLogger();
  defineAllTests(context);
}
