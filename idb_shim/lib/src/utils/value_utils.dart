import 'dart:math';

/// true if [value1] is less than [value2]
bool lessThan(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp != null && cmp < 0;
}

/// true if [value1] is greater then [value2]
bool greaterThan(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp != null && cmp > 0;
}

/// true if [value1] equals [value2]
bool equals(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp == 0;
}

/// Compare 2 values.
///
/// return <0 if value1 < value2 or >0 if greater
/// returns null if cannot be compared
int compareValue(dynamic value1, dynamic value2) {
  try {
    if (value1 is Comparable && value2 is Comparable) {
      return Comparable.compare(value1, value2);
    } else if (value1 is List && value2 is List) {
      final list1 = value1;
      final list2 = value2;

      for (var i = 0; i < min(value1.length, value2.length); i++) {
        final cmp = compareValue(list1[i], list2[i]);
        if (cmp == 0) {
          continue;
        }
        return cmp;
      }
      // Same ? return the length diff if any
      return compareValue(list1.length, list2.length);
    }
  } catch (_) {}
  return null;
}
