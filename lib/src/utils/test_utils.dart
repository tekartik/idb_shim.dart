@deprecated
library idb_shim_test_utils;

import 'package:unittest/unittest.dart' as unittest;
export 'package:unittest/unittest.dart' hide solo_test, solo_group;
export 'dev_utils.dart';

@deprecated
solo_test(spec, dynamic body()) {
  unittest.solo_test(spec, body);
}

@deprecated
solo_group(spec, dynamic body()) {
  unittest.solo_group(spec, body);
}