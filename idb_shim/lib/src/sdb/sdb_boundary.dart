import 'sdb_boundary_impl.dart';

/// Simple boundary definition. include default to true for lower boundary and
/// false for upper boundary.
abstract class SdbBoundary<T extends Object> {
  /// if true, the boundary will be included in the search result.
  ///
  /// defaults to true for lower boundary and false for upper boundary.
  bool get include;

  /// Boundary value.
  T get value;
}

/// Lower boundary. (included by default).
abstract class SdbLowerBoundary<T extends Object> extends SdbBoundary<T> {
  /// Create a boundary from a [value]
  ///
  /// if [include] is true or null, the value at the boundary will be included.
  factory SdbLowerBoundary(T value, {bool? include = true}) {
    return DbBoundaryImpl(value, include ?? true);
  }
}

/// Upper boundary. (excluded by default).
abstract class SdbUpperBoundary<T extends Object> extends SdbBoundary<T> {
  /// Create a boundary from a [value]
  ///
  /// if [include] is true (not null), the value at the boundary will be included.
  factory SdbUpperBoundary(T value, {bool? include = false}) {
    return DbBoundaryImpl(value, include ?? false);
  }
}

/// Lower and upper boundaries.
abstract class SdbBoundaries<T extends Object> {
  /// Lower boundary.
  SdbBoundary<T>? get lower;

  /// Upper boundary.
  SdbBoundary<T>? get upper;

  /// Create boundaries from a lower and upper  boundary.
  factory SdbBoundaries(SdbBoundary<T>? lower, SdbBoundary<T>? upper) =>
      SdbBoundariesImpl(lower, upper);

  /// Create boundaries from an lower (included) and upper (excluded) boundary.
  factory SdbBoundaries.values(
    T? lower,
    T? upper, {
    bool? includeLower,
    bool? includeUpper,
  }) => SdbBoundariesImpl(
    lower == null ? null : SdbLowerBoundary(lower, include: includeLower),
    upper == null ? null : SdbUpperBoundary(upper, include: includeUpper),
  );

  /// Lower only boundary.
  factory SdbBoundaries.lowerValue(T lower) =>
      SdbBoundariesImpl(SdbLowerBoundary(lower), null);

  /// Lower only boundary.
  factory SdbBoundaries.lower(SdbBoundary<T>? lower) =>
      SdbBoundariesImpl(lower, null);

  /// Upper only boundary.
  factory SdbBoundaries.upperValue(T upper) =>
      SdbBoundariesImpl(null, SdbUpperBoundary(upper));

  /// Upper only boundary.
  factory SdbBoundaries.upper(SdbBoundary<T>? upper) =>
      SdbBoundariesImpl(null, upper);

  /// Single key boundary used in index search.
  factory SdbBoundaries.key(T key) {
    return SdbSingleKeyBoundaries(key);
    //final keyBoundary SdbBoundary<T> boundary = SdbLowerBoundary<T>(key);
  }

  /// Returns a string representation of the boundaries like '0 <= ? < 1'.
  String toConditionString();
}
