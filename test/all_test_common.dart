library all_test_common;

import 'package:unittest/unittest.dart';

import 'open_test.dart' as open_test;
import 'database_test.dart' as database_test;
import 'transaction_test.dart' as transaction_test;
import 'cursor_test.dart' as cursor_test;
import 'key_range_test.dart' as key_range_test;
import 'object_store_test.dart' as object_store_test;
import 'index_test.dart' as index_test;
import 'index_cursor_test.dart' as index_cursor_test;
import 'simple_provider_test.dart' as simple_provider_test;
import 'factory_test.dart' as factory_test;
import 'quick_standalone_test.dart' as quick_standalone_test;
import 'indexeddb_1_test.dart' as indexeddb_1_test;
import 'indexeddb_2_test.dart' as indexeddb_2_test;
import 'indexeddb_3_test.dart' as indexeddb_3_test;
import 'indexeddb_4_test.dart' as indexeddb_4_test;
import 'indexeddb_5_test.dart' as indexeddb_5_test;
import 'package:idb_shim/idb_client.dart';

testMain(IdbFactory idbFactory) {

  transaction_test.testMain(idbFactory);
  cursor_test.testMain(idbFactory);
  open_test.testMain(idbFactory);
  database_test.testMain(idbFactory);
  object_store_test.testMain(idbFactory);
  key_range_test.testMain(idbFactory);
  factory_test.testMain(idbFactory);
  index_test.defineTests(idbFactory);
  index_cursor_test.defineTests(idbFactory);
  simple_provider_test.testMain(idbFactory);
  quick_standalone_test.defineTests(idbFactory);

  group('indexeddb_1', () {
    indexeddb_1_test.testMain(idbFactory);
  });
  group('indexeddb_2', () {
    indexeddb_2_test.testMain(idbFactory);
  });
  group('indexeddb_3', () {
    indexeddb_3_test.testMain(idbFactory);
  });
  group('indexeddb_4', () {
    indexeddb_4_test.testMain(idbFactory);
  });
  group('indexeddb_5', () {
    indexeddb_5_test.testMain(idbFactory);
  });

}
