/// Compat, prefer IdbCursor
typedef Cursor = IdbCursor;

/// Compat, prefer IdbCursorWithValue
typedef CursorWithValue = IdbCursorWithValue;

///
/// represents a cursor for traversing or iterating over multiple records in a
/// database.
///
/// The cursor has a source that indicates which index or object store it is
/// iterating over. It has a position within the range, and moves in a direction
/// that is increasing or decreasing in the order of record keys. The cursor
/// enables an application to asynchronously process all the records in the
/// cursor's range.
///
/// You can have an unlimited number of cursors at the same time. You always get
/// the same IDBCursor object representing a given cursor. Operations are
/// performed on the underlying index or object store.
///
abstract class IdbCursor {
  ///
  /// returns the key for the record at the cursor's position. If the cursor is
  /// outside its range, this is set to undefined. The cursor's key can be
  /// any data type
  ///
  /// idb_shim: specific - key must be num or String
  ///
  Object get key;

  ///
  /// returns the cursor's current effective key. If the cursor is currently
  /// being iterated or has iterated outside its range, this is set to undefined.
  /// The cursor's primary key can be any data type.
  ///
  /// idb_shim: specific - key must be num or String
  ///
  Object get primaryKey;

  ///
  /// returns the direction of traversal of the cursor (set using
  /// [ObjectStore.openCursor] for example).
  ///
  /// idb_shim: next, prev supported only (not nextunique, prevunique)
  ///
  String get direction;

  ///
  /// sets the number times a cursor should move its position forward.
  ///
  void advance(int count);

  ///
  /// advances the cursor to the next position along its direction, to the item
  /// whose key matches the optional key parameter. If no key is specified,
  /// the cursor advances to the immediate next position, based on the its
  /// direction.
  ///
  void next();

  ///
  /// updates the value at the current position of the cursor in the object
  /// store. If the cursor points to a record that has just been deleted,
  /// a new record is created.
  ///
  Future<void> update(Object value);

  ///
  /// deletes the record at the cursor's position, without changing the cursor's
  /// position. Once the record is deleted, the cursor's value is set to null.
  ///
  Future<void> delete();
}

///
/// represents a cursor for traversing or iterating over multiple records in a
/// database. It is the same as the [Cursor], except that it includes the value
/// property.
///
/// The cursor has a source that indicates which index or object store it is
/// iterating over. It has a position within the range, and moves in a direction
/// that is increasing or decreasing in the order of record keys. The cursor
/// enables an application to asynchronously process all the records in the
/// cursor's range.
///
/// You can have an unlimited number of cursors at the same time. You always get
/// the same CursorWithValue object representing a given cursor. Operations are
/// performed on the underlying index or object store.
///
abstract class IdbCursorWithValue extends Cursor {
  /// Returns the value of the current cursor.
  Object get value;
}

/// Matching function for a cursor with value.
typedef IdbCursorWithValueMatcherFunction =
    bool Function(IdbCursorWithValue cursor);
