@TestOn('chrome')
library;

import 'package:idb_shim/sdb.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/src/stress_notes_db_test.dart';

Future<void> main() async {
  var factory = sdbFactoryWeb;

  sdbStressNotesGroup(factory);
  sdbStressAddListNotesGroup(factory, addedCount: [100, 2000, 5000]);
}
