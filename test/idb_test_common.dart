library idb_test_common;

import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

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