library common_value_test;

import 'package:idb_shim/src/common/common_value.dart';
import 'idb_test_common.dart';

void main() => defineTests();

void defineTests() {
  group('value', () {
    test('Map', () {
      expect(encodeValue({}), "{}");
    });

    test('String', () {
      expect(encodeValue("test"), '"test"');
    });

    test('int', () {
      expect(encodeValue(1), "1");
    });

    // not supported
    test('DateTime', () {
      try {
        expect(encodeValue(DateTime.now()), "xxxx");
        fail("should fail");
      } catch (e) {
        //devPrint(e);
      }
    });
  });
}
