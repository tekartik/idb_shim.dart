library;

import 'package:idb_shim/src/utils/value_utils.dart';
import 'package:idb_shim/src/utils/value_utils.dart' as utils;
import 'package:test/test.dart';

void main() {
  group('value_utils', () {
    test('compare', () {
      expect(compareValue('1', '2'), Comparable.compare('1', '2'));
      expect(compareValue(1, 2), Comparable.compare(1, 2));
      expect(compareValue(1, '2'), isNull);

      // compareValue
      expect(compareValue([0], [0]), 0);
    });

    test('equals', () {
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.equals(0, 0), isTrue);
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.equals(0, 1), isFalse);

      // array
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.equals([0], [0]), isTrue);
    });

    test('lessThen', () {
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan(0, 1), isTrue);
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan(0, 0), isFalse);

      // array
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan([0], [1]), isTrue);
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan([0], [0, 0]), isTrue);
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan([0], [0]), isFalse);
    });
  });
}
