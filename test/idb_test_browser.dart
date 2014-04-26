library idb_test_browser;

import 'package:unittest/html_config.dart' as cfg;
import 'package:unittest/unittest.dart';
import 'idb_test_common.dart';

final _configuration = new IdbHtmlConfiguration();

void useHtmlConfiguration() {
  unittestConfiguration = _configuration;
}

class IdbHtmlConfiguration extends cfg.HtmlConfiguration with IdbDebugConfiguration {
  
  IdbHtmlConfiguration() : super(false) {
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
//import 'package:idb_shim/idb_client.dart';

//IdbFactory idbFactory;