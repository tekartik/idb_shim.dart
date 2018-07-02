library key_range_test;

import 'idb_test_common.dart';
import 'package:idb_shim/idb_client.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  group('KeyRange', () {
    setUp(() {});

    test('only', () {
      KeyRange keyRange = new KeyRange.only(1);
      expect(keyRange.lower, equals(1));
      expect(keyRange.lowerOpen, isFalse);
      expect(keyRange.upper, equals(1));
      expect(keyRange.upperOpen, isFalse);
      var range = keyRange;
      expect(range.contains(1), isTrue);
      expect(range.contains(0), isFalse);
      expect(range.contains(2), isFalse);
    });

    test('lowerOpen', () {
      KeyRange keyRange = new KeyRange.lowerBound(1, true);
      expect(keyRange.lower, equals(1));
      expect(keyRange.lowerOpen, isTrue);
      //TODO expect(keyRange.upper, isNull);
      expect(keyRange.upperOpen, isTrue);
      var range = keyRange;
      expect(range.contains(1), isFalse);
      expect(range.contains(0), isFalse);
      expect(range.contains(2), isTrue);
    });

    test('lowerClose', () {
      KeyRange keyRange = new KeyRange.lowerBound(1, false);
      var range = keyRange;
      expect(range.contains(1), isTrue);
      expect(range.contains(0), isFalse);
      expect(range.contains(2), isTrue);
    });

    test('upperOpen', () {
      KeyRange keyRange = new KeyRange.upperBound(3, true);
      var range = keyRange;
      expect(range.contains(2), isTrue);
      expect(range.contains(3), isFalse);
      expect(range.contains(4), isFalse);
    });

    test('upper', () {
      KeyRange keyRange = new KeyRange.upperBound(3);
      //TODO expect(keyRange.lower, isNull);
      expect(keyRange.lowerOpen, isTrue);
      expect(keyRange.upper, equals(3));
      expect(keyRange.upperOpen, isFalse);
      var range = keyRange;
      expect(range.contains(2), isTrue);
      expect(range.contains(3), isTrue);
      expect(range.contains(4), isFalse);
    });

    test('lower/upper', () {
      KeyRange keyRange = new KeyRange.bound(1, 3);
      var range = keyRange;
      expect(range.contains(1), isTrue);
      expect(range.contains(3), isTrue);
      expect(range.contains(4), isFalse);
      expect(range.contains(0), isFalse);
    });
  });
}
