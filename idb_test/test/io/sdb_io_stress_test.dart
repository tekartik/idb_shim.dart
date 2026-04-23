@TestOn('vm')
library;

import 'package:idb_shim/sdb.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/src/stress_notes_db_test.dart';

Future<void> main() async {
  var factory = sdbFactoryIo;

  var path = '.local/sqflite_io_stress';

  sdbStressNotesGroup(factory, path: path);
  sdbStressAddListNotesGroup(factory, path: path, addedCount: [50, 1000]);
}
