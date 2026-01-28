import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  group('store', () {
    test('equals', () async {
      var store1 = SdbStoreRef<int, String>('test');
      var store2 = SdbStoreRef<String, int>('test');
      expect(store1, store2);
      expect(store1.hashCode, store2.hashCode);
    });
  });
  group('record', () {
    test('equals', () async {
      var record1 = SdbStoreRef<int, String>('test').record(1);
      var record2 = SdbStoreRef<int, int>('test').record(1);
      expect(record1, record2);
      expect(record1.hashCode, record2.hashCode);
    });
  });
}
