library;

import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';
import 'package:sembast_web/utils/jdb.dart';

void main() {
  var context = SembastTestContext(
    sembastDatabaseFactory: DatabaseFactoryJdb(JdbFactoryIdb(idbFactoryMemory)),
  );

  defineAllTests(context);
}
