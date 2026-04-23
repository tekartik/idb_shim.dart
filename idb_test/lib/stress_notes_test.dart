import 'dart:core';
import 'dart:core' as core;

import 'package:idb_shim/sdb.dart';
import 'package:idb_test/src/stress_notes_db_test.dart';

Future<void> main() async {
  var factory = sdbFactoryMemory;
  sdbStressNotesGroup(factory);
}
