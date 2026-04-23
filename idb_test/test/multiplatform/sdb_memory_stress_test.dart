import 'package:idb_shim/sdb.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/src/stress_notes_db_test.dart';

Future<void> main() async {
  var factory = sdbFactoryMemory;

  sdbStressNotesGroup(factory);
  sdbStressAddListNotesGroup(factory, addedCount: [2000]);
}
