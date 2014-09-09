library idb_test_common;

import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';
import 'package:idb_shim/idb_client.dart';

export 'package:idb_shim/src/utils/test_utils.dart';

// only for test - INFO - basic output, FINE - show test name before/after - FINEST - samething for console test also
const Level DEBUG_LEVEL = Level.FINE;
const String DB_NAME = 'test.db';
const String STORE_NAME = 'test_store';
const String STORE_NAME_2 = 'test_store_2';

const String NAME_INDEX = 'name_index';
const String NAME_FIELD = 'name';

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
