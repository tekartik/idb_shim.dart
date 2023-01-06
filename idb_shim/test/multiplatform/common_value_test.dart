library common_value_test;

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_value.dart';

import '../idb_test_common.dart';

void main() => defineTests();

void defineTests() {
  group('value', () {
    test('Map', () {
      expect(encodeValue({}), '{}');
    });

    test('String', () {
      expect(encodeValue('test'), '"test"');
      expect(encodeValue("'test'"), '"\'test\'"');
      expect(encodeValue('"test"'), '"\\"test\\""');
    });

    test('int', () {
      expect(encodeValue(1), '1');
    });

    // not supported
    test('DateTime', () {
      try {
        expect(encodeValue(DateTime.now()), 'xxxx');
        fail('should fail');
      } catch (e) {
        //devPrint(e);
      }
    });

    test('keyArrayRangeAt', () {
      var keyRange = keyArrayRangeAt(KeyRange.only([1]), 0);
      expect(keyRange.lower, 1);
      expect(keyRange.upper, 1);
      keyRange = keyArrayRangeAt(KeyRange.lowerBound([1], false), 0);
      expect(keyRange.lower, 1);
      expect(keyRange.upper, null);
      keyRange = keyArrayRangeAt(KeyRange.upperBound(['John'], false), 0);
      expect(keyRange.lower, null);
      expect(keyRange.upper, 'John');
    });

    test('IdbValueMapExt', () {
      var map = <String, Object?>{'key': 1};
      expect(map.getFieldValue('key'), 1);
      expect(map.getKeyValue('key'), 1);
      expect(map.getKeyValue(['key']), [1]);
      map.setKeyValue('key', 2);
      expect(map.getKeyValue(['key']), [2]);
      map.setKeyValue(['key'], [3]);
      expect(map.getKeyValue('key'), 3);
      expect(map, {'key': 3});
      map.setKeyValue('my', 'text');
      expect(map, {'key': 3, 'my': 'text'});
      map.setKeyValue(['my', 'key'], [4, 'text']);
      expect(map.getKeyValue(['my', 'key']), [4, 'text']);
      expect(map, {'key': 'text', 'my': 4});
      map.setFieldValue('my', 1);
      expect(map, {'key': 'text', 'my': 1});
    });
  });
}
