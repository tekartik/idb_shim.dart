library common_value_test;

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_value.dart';

import '../idb_test_common.dart';

void main() => defineTests();

void defineTests() {
  group('value', () {
    test('Map', () {
      expect(encodeValue(<String, Object?>{}), '{}');
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

    test('KeyRangeBound', () {
      try {
        KeyRange.bound(1, 1, false, true);
        fail('should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }
      try {
        KeyRange.bound('test', 'test', true, false);
        fail('should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }
    });

    void expectThrow(KeyRange Function() action) {
      expect(action, throwsA(isA<DatabaseError>()));
    }

    test('KeyRangeLowerBound', () {
      //expectThrow(() => KeyRange.lowerBound(null, false));
      //expectThrow(() => KeyRange.lowerBound(null, true));
      expectThrow(() => KeyRange.lowerBound([1, null], false));
      expectThrow(() => KeyRange.lowerBound([1, null], true));
      KeyRange.lowerBound([1, 1], false);
      KeyRange.lowerBound([1, 1], true);
    });

    test('KeyRangeUpperBound', () {
      //expectThrow(() => KeyRange.upperBound(null, false));
      //expectThrow(() => KeyRange.upperBound(null, true));
      expectThrow(() => KeyRange.upperBound([1, null], false));
      expectThrow(() => KeyRange.upperBound([1, null], true));
      KeyRange.upperBound([1, 1], false);
      KeyRange.upperBound([1, 1], true);
    });

    test('KeyRangeBound', () {
      //expectThrow(() => KeyRange.bound(1, null, true, true));
      //expectThrow(() => KeyRange.bound(null, 1, true, true));
      expectThrow(() => KeyRange.bound([1, 0], [1, null], true, true));
      expectThrow(() => KeyRange.bound([1, null], [1, 2], true, true));
      KeyRange.bound(1, 2, false, false);
      KeyRange.bound(1, 2, true, true);
    });

    test('keyArrayRangeAt', () {
      var keyRange = compositeKeyRangeAt(KeyRange.only([1]), 0);
      expect(keyRange.lower, 1);
      expect(keyRange.upper, 1);
      keyRange = compositeKeyRangeAt(KeyRange.lowerBound([1], false), 0);
      expect(keyRange.lower, 1);
      expect(keyRange.upper, null);
      keyRange = compositeKeyRangeAt(KeyRange.upperBound(['John'], false), 0);
      expect(keyRange.lower, null);
      expect(keyRange.upper, 'John');
    });

    test('IdbValueMapExt', () {
      var map = <String, Object?>{'key': 1};
      expect(map.getFieldValue<int>('key'), 1);
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
