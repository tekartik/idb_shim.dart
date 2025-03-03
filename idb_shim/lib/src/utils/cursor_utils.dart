library;

import 'package:idb_shim/src/cursor.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/utils/value_utils.dart';

export 'package:idb_shim/idb_shim.dart';

/// Compat, prefer IdbCursorRow
typedef CursorRow = IdbCursorRow;

/// Compat, prefer IdbCursorRow
typedef KeyCursorRow = IdbKeyCursorRow;

/// Cursor row.
class IdbCursorRow extends KeyCursorRow {
  /// Cursor row value.
  final Object value;

  /// Create a cursor row with a [key], [primaryKey] and [value].
  IdbCursorRow(super.key, super.primaryKey, this.value);

  @override
  String toString() {
    return '$value';
  }
}

/// Key cursor row.
class IdbKeyCursorRow {
  /// Cursor row key.
  ///
  /// This is the index key if the cursor is open on an index. Otherwise, it is
  /// the primary key.
  final dynamic key;

  /// Cursory row primary key.
  final dynamic primaryKey;

  @override
  String toString() {
    return '$key $primaryKey';
  }

  /// Create a cursor row with a [key], and [primaryKey].
  IdbKeyCursorRow(this.key, this.primaryKey);
}

/// Helper extension
extension IdbCursorRowIterableExt on Iterable<IdbCursorRow> {
  /// Convert a list of cursor row to a list of values.
  Iterable<Object> get values => map((row) => row.value);
}

/// Extension on [`Stream<Cursor>`]. Cursor must not be in auto-advanced mode.
extension CursorWithValueStreamExt on Stream<CursorWithValue> {
  /// Convert an openCursor stream to a list.
  Future<List<CursorRow>> toRowList({
    int? limit,
    int? offset,
    IdbCursorWithValueMatcherFunction? matcher,
  }) {
    CursorRow? getRow(CursorWithValue cwv) {
      if (matcher != null && !matcher(cwv)) {
        return null;
      }
      var value = cloneValue(cwv.value);
      return CursorRow(cwv.key, cwv.primaryKey, value);
    }

    return _cursorStreamToList(
      this,
      (cwv) => getRow(cwv),
      offset: offset,
      limit: limit,
    );
  }

  /// Convert an openKeyCursor stream to a list (must be auto-advance)
  Future<List<Object>> toValueList({int? limit, int? offset}) =>
      _cursorStreamToList(
        this,
        (cursor) => cursor.value,
        offset: offset,
        limit: limit,
      );
}

/// Extension on [`Stream<Cursor>`]. Cursor must not be in auto-advanced mode.
extension CursorStreamExt<C extends Cursor> on Stream<C> {
  /// Convert an openKeyCursor stream to a list
  Future<List<KeyCursorRow>> toKeyRowList({int? limit, int? offset}) =>
      _cursorStreamToList(
        this,
        (cursor) => KeyCursorRow(cursor.key, cursor.primaryKey),
        offset: offset,
        limit: limit,
      );

  /// Convert an openKeyCursor stream to a list of key, must be auto-advance)
  Future<List<Object>> toPrimaryKeyList({int? limit, int? offset}) =>
      _cursorStreamToList(
        this,
        (cursor) => cursor.primaryKey,
        offset: offset,
        limit: limit,
      );

  /// Convert an openKeyCursor stream to a list (must be auto-advance)
  Future<List<Object>> toKeyList({int? limit, int? offset}) =>
      _cursorStreamToList(
        this,
        (cursor) => cursor.key,
        offset: offset,
        limit: limit,
      );
}

/// Convert an openCursor stream to a list. Warning the cursor must not be auto-advanced !
Future<List<T>> _cursorStreamToList<C extends Cursor, T>(
  Stream<C> stream,
  T? Function(C cursor) convert, {

  int? offset,
  int? limit,
}) {
  var completer = Completer<List<T>>.sync();
  final list = <T>[];
  var first = true;
  stream.listen(
    (C cursor) {
      if (first && (offset != null) && (offset != 0)) {
        first = false;
        cursor.advance(offset);
      } else {
        if (limit == null || (list.length < limit)) {
          var row = convert(cursor);

          /// Null typically means that the row was filtered out
          /// using a matcher
          if (row != null) {
            list.add(row);
          }
        }
        if (limit != null && list.length >= limit) {
          // Go far deep in the future, not a better trick yet
          // With a value higher than 0xFFFFFFFF, it does not work on native: Error: Failed to execute 'advance' on 'IDBCursor': Value is outside the 'unsigned long' value range.
          cursor.advance(0xFFFFFFFF);
        } else {
          cursor.advance(1);
        }
      }
    },
    onDone: () {
      completer.complete(list);
    },
    cancelOnError: true,
    onError: (Object e, StackTrace st) {
      completer.completeError(e, st);
    },
  );
  return completer.future;
}
