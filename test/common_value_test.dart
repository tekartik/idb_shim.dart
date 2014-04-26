library common_value_test;

import 'package:unittest/unittest.dart';

import 'package:idb_shim/src/common/common_value.dart';

void main() {

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
    skip_test('DateTime', () {
      expect(encodeValue(new DateTime.now()), "xxxx");
    });

  });
}
