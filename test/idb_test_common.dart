library idb_test_common;

import 'package:tekartik_test/test_config.dart';
import 'package:logging/logging.dart';
//import 'package:unittest/unittest.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/utils/test_utils.dart';
export 'package:idb_shim/idb_client_memory.dart';
import 'dart:async';
export 'dart:async';
export 'package:tekartik_test/test_utils.dart';

// only for test - INFO - basic output, FINE - show test name before/after - FINEST - samething for console test also
const Level DEBUG_LEVEL = Level.FINE;
const String DB_NAME = 'test.db';
const String STORE_NAME = 'test_store';
const String STORE_NAME_2 = 'test_store_2';

const String NAME_INDEX = 'name_index';
const String NAME_FIELD = 'name';
const String NAME_INDEX_2 = 'name_index_2';
const String NAME_FIELD_2 = 'name_2';


Future<Database> setUpSimpleStore(IdbFactory idbFactory) {
  return idbFactory.deleteDatabase(DB_NAME).then((_) {
    void _initializeDatabase(VersionChangeEvent e) {
      Database db = e.database;
      ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
    }
    return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase);
  });
}

abstract class IdbDebugConfiguration {

  void debugOnCreate(Configuration configuration) {
    configuration.timeout = new Duration(seconds: 10); // consider 30 sometimes
  }

  void debugOnTestStart(TestCase testCase) {
    if (DEBUG_LEVEL <= Level.FINE) {
      print(testCase.description + " - started");
    }
  }

  void debugOnTestResult(TestCase testCase) {
    if (DEBUG_LEVEL <= Level.FINE) {
      if (!testCase.message.isEmpty) {
        print(testCase.description + " - " + testCase.message);
      } else {
        if (DEBUG_LEVEL <= Level.FINE) {
          print(testCase.description + " - ok");
        }
      }
    }
  }
}

bool isTransactionReadOnlyError(e) {
  if (e is DatabaseError) {
    String message = e.toString().toLowerCase();
    if (message.contains('readonly')) {
      return true;
    }
    if (message.contains('read_only')) {
      return true;
    }
  }
  return false;
}

bool isStoreNotFoundError(e) {
  if (e is DatabaseError) {
    String message = e.toString().toLowerCase();
    if (message.contains('notfounderror')) {
      return true;
    }
  }
  return false;
}
