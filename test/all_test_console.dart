library all_test_console;

//import 'package:unittest/compact_vm_config.dart';
import 'all_test_common.dart';
import 'idb_test_console.dart';
import 'common_value_test.dart' as common_value_test;
import 'package:tekartik_idb/idb_console.dart';
import 'package:tekartik_idb/idb_client.dart';

void main() {
  useVMConfiguration();
  //useCompactVMConfiguration();
  
  IdbFactory idbFactory = idbMemoryFactory;
  testMain(idbFactory);
  common_value_test.main();
}