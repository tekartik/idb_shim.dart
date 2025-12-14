import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';

void main() {
  group('SdbBoundary', () {
    test('simple', () async {
      SdbBoundary<int> boundary = SdbLowerBoundary(0);
      expect(boundary.toString(), '0 (included)');
      expect(boundary.value, 0);
      expect(boundary.include, isTrue);
      boundary = SdbUpperBoundary(1);
      expect(boundary.toString(), '1 (excluded)');
      expect(boundary.value, 1);
      expect(boundary.include, isFalse);
    });
    test('boundaries', () {
      expect(SdbBoundaries.values(0, 1).toConditionString(), '0 <= ? < 1');
      expect(SdbBoundaries<int>.values(0, null).toConditionString(), '0 <= ?');
      expect(SdbBoundaries<int>.values(null, 1).toConditionString(), '? < 1');
      expect(SdbBoundaries.values(0, 1).toConditionString(), '0 <= ? < 1');
      expect(SdbBoundaries<int>(null, null).toConditionString(), '?');
      expect(SdbBoundaries.lowerValue(0).toConditionString(), '0 <= ?');
      expect(SdbBoundaries.key(1).toConditionString(), '? == 1');
    });
  });
}
