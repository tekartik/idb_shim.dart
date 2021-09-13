library key_range_test;

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

bool keyRangeContains(KeyRange keyRange, Object key) {
  // ignore: invalid_use_of_protected_member
  return keyRange.contains(key);
}

void defineTests(TestContext ctx) {
  group('KeyRange', () {
    setUp(() {});

    test('only', () {
      final keyRange = KeyRange.only(1);
      expect(keyRange.lower, equals(1));
      expect(keyRange.lowerOpen, isFalse);
      expect(keyRange.upper, equals(1));
      expect(keyRange.upperOpen, isFalse);
      var range = keyRange;
      // ignore: deprecated_member_use_from_same_package
      expect(keyRangeContains(range, 1), isTrue);
      // ignore: deprecated_member_use_from_same_package
      expect(keyRangeContains(range, 0), isFalse);
      // ignore: deprecated_member_use_from_same_package
      expect(keyRangeContains(range, 2), isFalse);
    });

    test('array', () {
      final keyRange = KeyRange.only([2018, 'John']);
      expect(keyRange.lower, [2018, 'John']);
      expect(keyRangeContains(keyRange, [2018, 'John']), isTrue);
    });

    test('lowerOpen', () {
      final keyRange = KeyRange.lowerBound(1, true);
      expect(keyRange.lower, equals(1));
      expect(keyRange.lowerOpen, isTrue);
      //TODO expect(keyRange.upper, isNull);
      expect(keyRange.upperOpen, isTrue);
      var range = keyRange;
      expect(keyRangeContains(range, 1), isFalse);
      expect(keyRangeContains(range, 0), isFalse);
      expect(keyRangeContains(range, 2), isTrue);
    });

    test('lowerClose', () {
      final keyRange = KeyRange.lowerBound(1, false);
      var range = keyRange;
      expect(keyRangeContains(range, 1), isTrue);
      expect(keyRangeContains(range, 0), isFalse);
      expect(keyRangeContains(range, 2), isTrue);
    });

    test('upperOpen', () {
      final keyRange = KeyRange.upperBound(3, true);
      var range = keyRange;
      expect(keyRangeContains(range, 2), isTrue);
      expect(keyRangeContains(range, 3), isFalse);
      expect(keyRangeContains(range, 4), isFalse);
    });

    test('upper', () {
      final keyRange = KeyRange.upperBound(3);
      //TODO expect(keyRange.lower, isNull);
      expect(keyRange.lowerOpen, isTrue);
      expect(keyRange.upper, equals(3));
      expect(keyRange.upperOpen, isFalse);
      var range = keyRange;
      expect(keyRangeContains(range, 2), isTrue);
      expect(keyRangeContains(range, 3), isTrue);
      expect(keyRangeContains(range, 4), isFalse);
    });

    test('lower/upper', () {
      final keyRange = KeyRange.bound(1, 3);
      var range = keyRange;
      expect(keyRangeContains(range, 1), isTrue);
      expect(keyRangeContains(range, 3), isTrue);
      expect(keyRangeContains(range, 4), isFalse);
      expect(keyRangeContains(range, 0), isFalse);
    });
  });
}
