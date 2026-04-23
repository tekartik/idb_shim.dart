import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/src/sdb/sdb_utils.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:idb_shim/utils/idb_cursor_utils.dart' as idb;

import '../../idb_client.dart' as idb;

/// Internal implementation of [idb.CursorRow].
class IdbCursorRowImpl implements idb.CursorRow {
  /// The underlying cursor with value.
  final idb.IdbCursorWithValue cwv;

  /// Create a cursor row from an idb cursor with value.
  IdbCursorRowImpl(this.cwv)
    : key = cwv.key,
      primaryKey = cwv.primaryKey,
      value = idbCloneValue(cwv.value);

  @override
  final Object key;

  @override
  final Object primaryKey;

  @override
  final Object value;

  @override
  String toString() {
    return 'IdbCursorRow(${logTruncateAny(primaryKey)}, ${logTruncateAny(key)}, ${logTruncateAny(value)})';
  }
}

/// Convert an openCursor stream to a list. Warning the cursor must not be auto-advanced !
/// cursor is ran 1 by 1
Stream<T> cursorApplyFilterLimitOffset<C extends idb.IdbCursor, T>(
  Stream<C> stream,
  FutureOr<T?> Function(C cursor) convert, {
  int? offset,
  int? limit,
}) {
  final controller = LimitOffsetControllerImpl<C, T>(
    offset: offset,
    limit: limit,
  );
  stream.listen(
    (C cursor) async {
      /// Convert first
      var row = convert(cursor);
      T? rowValue;
      if (row is Future) {
        rowValue = await row;
      } else {
        rowValue = row;
      }
      controller.next(cursor, rowValue);
    },
    onDone: () {
      controller.close();
    },
    cancelOnError: true,
    onError: (Object e, StackTrace st) {
      controller.addError(e, st);
    },
  );
  return controller.stream;
}

/// Controller to handle limit and offset on a cursor stream.
class LimitOffsetControllerImpl<C extends idb.IdbCursor, T> {
  /// Offset to skip.
  final int? offset;

  /// Limit of records to return.
  final int? limit;

  /// Current count of records added to the stream.
  var count = 0;

  /// Current offset applied.
  var offsetApplied = 0;

  /// Underlying cursor controller.
  final ctlr = CursorControllerImpl<C, T>();

  /// Create a limit/offset controller.
  LimitOffsetControllerImpl({this.offset, this.limit});

  /// Process the next row.
  void next(C cursor, T? row) {
    if (row == null) {
      cursor.advance(1);
      return;
    }
    // Apply offset and skip first if needed
    if ((offset ?? 0) > offsetApplied) {
      offsetApplied++;
      ctlr.next(cursor);
      return;
    }
    ctlr.add(row);
    count++;
    // handle limit
    if (limit != null) {
      if (count >= limit!) {
        ctlr.terminate(cursor);
        return;
      }
    }

    if (ctlr.canceled) {
      ctlr.terminate(cursor);
    } else {
      ctlr.next(cursor);
    }
  }

  /// The resulting stream.
  Stream<T> get stream => ctlr.stream;

  /// Close the controller.
  void close() {
    ctlr.close();
  }

  /// Add an error to the stream.
  void addError(Object e, StackTrace st) {
    ctlr.addError(e, st);
  }
}

/// Helper to control a cursor-based stream.
class CursorControllerImpl<C extends idb.IdbCursor, T> {
  /// True if the stream was canceled.
  var canceled = false;

  /// Handle stream cancellation.
  void onCancel() {
    canceled = true;
  }

  /// Underlying stream controller.
  late final ctlr = StreamController<T>(sync: true, onCancel: onCancel);

  /// The resulting stream.
  Stream<T> get stream => ctlr.stream;

  /// Add a value to the stream.
  void add(T value) {
    if (!canceled) {
      ctlr.add(value);
    }
  }

  /// Add an error to the stream.
  void addError(Object error, StackTrace stackTrace) {
    if (!canceled) {
      ctlr.addError(error, stackTrace);
    }
  }

  /// Terminate the cursor by advancing to the end.
  void terminate(idb.IdbCursor cursor) {
    // Go far deep in the future, not a better trick yet
    // With a value higher than 0xFFFFFFFF, it does not work on native: Error: Failed to execute 'advance' on 'IDBCursor': Value is outside the 'unsigned long' value range.
    cursor.advance(0xFFFFFFFF);
  }

  /// Advance to the next item.
  void next(idb.IdbCursor cursor) {
    cursor.advance(1);
  }

  /// Close the stream.
  void close() {
    ctlr.close();
  }
}
