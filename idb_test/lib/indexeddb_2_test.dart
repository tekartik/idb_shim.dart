// https://dart.googlecode.com/svn/branches/bleeding_edge/dart/tests/html/indexeddb_1_test.dart
// replace html.window.indexedDB with idbFactory
// replace IndexedDB1Test with IndexedDB2Test
library idb_shim.test.indexeddb_2_test;

import 'dart:collection';

import 'package:idb_shim/idb_client.dart' as idb;

import 'idb_test_common.dart';
import 'indexeddb_utils.dart';
// so that this can be run directly

// Write and re-read Maps: simple Maps; Maps with DAGs; Maps with cycles.

const String DB_NAME = 'Test2';
const String STORE_NAME = 'TEST';
const int VERSION = 1;

Future testReadWrite(idb.IdbFactory idbFactory, key, value, check,
    [String dbName = DB_NAME,
    String storeName = STORE_NAME,
    int version = VERSION]) async {
  void createObjectStore(idb.VersionChangeEvent e) {
    var store = e.database.createObjectStore(storeName);
    expect(store, isNotNull);
  }

  var db;
  // Delete any existing DBs.
  await idbFactory.deleteDatabase(dbName);

  try {
    db = await idbFactory.open(dbName,
        version: version, onUpgradeNeeded: createObjectStore);
    var transaction = db.transactionList([storeName], 'readwrite');
    transaction.objectStore(storeName).put(value, key);

    await transaction.completed;
    transaction = db.transaction(storeName, 'readonly');
    var object = await transaction.objectStore(storeName).getObject(key);
    db.close();
    db = null;
    check(value, object);
  } catch (e) {
    if (db != null) {
      db.close();
    }
    rethrow;
  }
}

List<String> get nonNativeListData {
  var list = <String>[];
  list.add('data');
  list.add('clone');
  list.add('error');
  list.add('test');
  return list;
}

void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;
  //useHtmlConfiguration();

  var obj1 = {'a': 100, 'b': 's'};
  var obj2 = {'x': obj1, 'y': obj1}; // DAG.

  var obj3 = {};
  obj3['a'] = 100;
  obj3['b'] = obj3; // Cycle.

  var obj4 = SplayTreeMap<String, dynamic>(); // Different implementation.
  obj4['a'] = 100;
  obj4['b'] = 's';

  final cyclicList = <Object>[1, 2, 3];
  cyclicList[1] = cyclicList;

  dynamic skipGo(name, data) => null;
  void go(String name, data) =>
      test(name, () => testReadWrite(idbFactory!, 123, data, verifyGraph));

  test('test_verifyGraph', () {
    // Nice to know verifyGraph is working before we rely on it.
    verifyGraph(obj4, obj4);
    verifyGraph(obj1, Map.from(obj1));
    verifyGraph(obj4, Map.from(obj4));

    var l1 = [1, 2, 3];
    var l2 = [
      const [1, 2, 3],
      const [1, 2, 3]
    ];
    verifyGraph([l1, l1], l2);
    expect(
        () => verifyGraph([
              [1, 2, 3],
              [1, 2, 3]
            ], l2),
        throwsA(anything));

    verifyGraph(cyclicList, cyclicList);
  });

  // Don't bother with these tests if it's unsupported.
  // Support is tested in indexeddb_1_test
  if (idb.IdbFactory.supported) {
    go('test_simple', obj1);
    skipGo('test_DAG', obj2);
    skipGo('test_cycle', obj3);
    go('test_simple_splay', obj4);
    go('const_array_1', const [
      [1],
      [2]
    ]);
    skipGo('const_array_dag', const [
      [1],
      [1]
    ]);
    skipGo('array_deferred_copy', [1, 2, 3, obj3, obj3, 6]);
    skipGo('array_deferred_copy_2', [
      1,
      2,
      3,
      [4, 5, obj3],
      [obj3, 6]
    ]);
    skipGo('cyclic_list', cyclicList);
    go('non-native lists', nonNativeListData);
  }
}
