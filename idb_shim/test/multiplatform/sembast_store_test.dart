library idb_shim.sembast_store_test;

import 'package:idb_shim/src/sembast/sembast_object_store.dart' as sembast;

import '../idb_test_common.dart';

void main() {
  group('sembast_object_store', () {
    test('getKeyImpl', () {
      var meta = IdbObjectStoreMeta('test', 'key', false);
      var store = sembast.ObjectStoreSembast(null, meta);
      expect(store.getKeyImpl({'key': 1}), 1);

      try {
        expect(store.getKeyImpl({'key': 1}, 1), 1);
        fail('should fail');
      } on ArgumentError catch (_) {}
    });
    test('getUpdateKeyIfNeeded', () {
      var meta = IdbObjectStoreMeta('test', 'key', false);
      var store = sembast.ObjectStoreSembast(null, meta);
      expect(store.getUpdateKeyIfNeeded({'key': 1}), isNull);
      expect(store.getUpdateKeyIfNeeded({'key': 1}, 1), isNull);
      expect(store.getUpdateKeyIfNeeded(null, null), isNull);
    });
  });
}
