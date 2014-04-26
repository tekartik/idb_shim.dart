library idb_test_console;

import 'package:unittest/vm_config.dart' as cfg;
import 'package:unittest/unittest.dart';
import 'idb_test_common.dart';

final _configuration = new IdbVMConfiguration();

void useVMConfiguration() {
  unittestConfiguration = _configuration;
}

class IdbVMConfiguration extends cfg.VMConfiguration with IdbDebugConfiguration {

  IdbVMConfiguration() {
    debugOnCreate(this);
  }

  @override
  void onTestStart(TestCase testCase) {
    debugOnTestStart(testCase);
    super.onTestStart(testCase);

  }

  @override
  void onTestResult(TestCase testCase) {
    debugOnTestResult(testCase);
    super.onTestResult(testCase);
  }

}
//import 'package:tekartik_idb/idb_client.dart';

//IdbFactory idbFactory;
