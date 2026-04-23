library;

import 'package:idb_shim/src/common/common_cursor.dart';
import 'package:idb_shim/src/cursor.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

export 'package:idb_shim/idb_shim.dart';

/// Compat, prefer IdbCursorRow
typedef CursorRow = IdbCursorRow;

/// Compat, prefer IdbCursorRow
typedef KeyCursorRow = IdbKeyCursorRow;

/// Cursor row.
abstract class IdbCursorRow extends KeyCursorRow {
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
  final Object key;

  /// Cursory row primary key.
  final Object primaryKey;

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

/// Extension on `Stream<Cursor>`. Cursor must not be in auto-advanced mode.
extension CursorWithValueStreamExt on Stream<CursorWithValue> {
  CursorRow _cursorRow(CursorWithValue cwv) {
    return IdbCursorRowImpl(cwv);
  }

  /// Map cursor to rows
  Stream<CursorRow> mapRows({IdbCursorWithValueMatcherFunction? matcher}) {
    return where(
      (cwv) => matcher == null || matcher(cwv),
    ).map((cwv) => _cursorRow(cwv));
  }

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
      return _cursorRow(cwv);
    }

    return _cursorStreamToList(
      this,
      (cwv) => getRow(cwv),
      offset: offset,
      limit: limit,
    );
  }

  CursorRow _cwvToRow(CursorWithValue cwv) {
    return IdbCursorRowImpl(cwv);
  }

  /// filter out.
  Stream<CursorRow> limitOffsetStream({
    int? limit,
    int? offset,
    IdbCursorWithValueMatcherFunction? matcher,
  }) {
    if (matcher == null) {
      return _cursorApplyLimitOffset(
        this,
        offset: offset,
        limit: limit,
      ).map(_cwvToRow);
    }
    CursorRow? checkAndConvertRow(CursorWithValue cwv) {
      if (!matcher(cwv)) {
        return null;
      }
      return _cwvToRow(cwv);
    }

    return _cursorApplyFilterLimitOffset(
      this,
      checkAndConvertRow,
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

/// Extension on `Stream<C extends Cursor>`. Cursor must not be in auto-advanced mode.
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
/// cursor is ran 1 by 1
Stream<T> _cursorApplyFilterLimitOffset<C extends Cursor, T>(
  Stream<C> stream,
  T? Function(C cursor) convert, {

  int? offset,
  int? limit,
}) {
  final ctlr = LimitOffsetControllerImpl<C, T>(offset: offset, limit: limit);

  stream.listen(
    (C cursor) {
      /// Convert first
      var row = convert(cursor);
      ctlr.next(cursor, row);
    },
    onDone: () {
      ctlr.close();
    },
    cancelOnError: true,
    onError: (Object e, StackTrace st) {
      ctlr.addError(e, st);
    },
  );
  return ctlr.stream;
}

/// Convert an openCursor stream to a list. Warning the cursor must not be auto-advanced !
Stream<C> _cursorApplyLimitOffset<C extends Cursor>(
  Stream<C> stream, {

  int? offset,
  int? limit,
}) {
  var first = true;
  var count = 0;
  var ctlr = CursorControllerImpl<C, C>();
  stream.listen(
    (C cursor) {
      if (first && (offset != null) && (offset != 0)) {
        first = false;
        if (ctlr.canceled) {
          ctlr.terminate(cursor);
        } else {
          cursor.advance(offset);
        }
      } else {
        if (limit == null || (count < limit)) {
          ctlr.add(cursor);
          count++;
        }
        if (limit != null && count >= limit) {
          ctlr.terminate(cursor);
        } else if (ctlr.canceled) {
          ctlr.terminate(cursor);
        } else {
          ctlr.next(cursor);
        }
      }
    },
    onDone: () {
      ctlr.close();
    },
    cancelOnError: true,
    onError: (Object e, StackTrace st) {
      ctlr.addError(e, st);
    },
  );
  return ctlr.stream;
}

/// Convert an openCursor stream to a list. Warning the cursor must not be auto-advanced !
Future<List<T>> _cursorStreamToList<C extends Cursor, T>(
  Stream<C> stream,
  T? Function(C cursor) convert, {

  int? offset,
  int? limit,
}) {
  return _cursorApplyFilterLimitOffset(
    stream,
    convert,
    offset: offset,
    limit: limit,
  ).toList();
}
