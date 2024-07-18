library idb_shim.test_runner;

import 'package:idb_test/sdb_test.dart';

import 'cursor_test.dart' as cursor_test;
import 'database_test.dart' as database_test;
import 'exception_test.dart' as exception_test;
import 'factory_test.dart' as factory_test;
import 'idb_test_common.dart';
import 'index_cursor_test.dart' as index_cursor_test;
import 'index_test.dart' as index_test;
import 'indexeddb_1_test.dart' as indexeddb_1_test;
import 'indexeddb_2_test.dart' as indexeddb_2_test;
import 'indexeddb_3_test.dart' as indexeddb_3_test;
import 'indexeddb_4_test.dart' as indexeddb_4_test;
import 'indexeddb_5_test.dart' as indexeddb_5_test;
import 'key_range_test.dart' as key_range_test;
import 'object_store_test.dart' as object_store_test;
import 'open_test.dart' as open_test;
import 'quick_standalone_test.dart' as quick_standalone_test;
import 'scenario_test.dart' as scenario_test;
import 'simple_provider_test.dart' as simple_provider_test;
import 'transaction_test.dart' as transaction_test;
import 'type_test.dart' as type_test;
import 'utils_test.dart' as utils_test;

void defineAllTests(TestContext ctx) {
  database_test.defineTests(ctx);
  index_cursor_test.defineTests(ctx);
  transaction_test.defineTests(ctx);
  cursor_test.defineTests(ctx);
  open_test.defineTests(ctx);
  object_store_test.defineTests(ctx);
  key_range_test.defineTests(ctx);
  factory_test.defineTests(ctx);
  index_test.defineTests(ctx);
  simple_provider_test.defineTests(ctx);
  quick_standalone_test.defineTests(ctx);
  scenario_test.defineTests(ctx);
  utils_test.defineTests(ctx);
  exception_test.defineTests(ctx);
  type_test.defineTests(ctx);
  simpleDbTest(ctx.factory);

  group('indexeddb_1', () {
    indexeddb_1_test.defineTests(ctx);
  });
  group('indexeddb_2', () {
    indexeddb_2_test.defineTests(ctx);
  });
  group('indexeddb_3', () {
    indexeddb_3_test.defineTests(ctx);
  });
  group('indexeddb_4', () {
    indexeddb_4_test.defineTests(ctx);
  });
  group('indexeddb_5', () {
    indexeddb_5_test.defineTests(ctx);
  });
}
