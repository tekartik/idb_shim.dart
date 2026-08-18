import 'package:idb_shim/src/common/common_cursor.dart';
import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/src/sdb/sdb_filter_impl.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import 'import_idb.dart' as idb;
import 'sdb.dart';

/// Cursor row handler. Return true to continue, false to stop
typedef SdbCursorRowHandler<K extends SdbKey, V extends SdbValue> =
    FutureOr<bool> Function(SdbCursorRow<K, V> row);

/// SimpleDb cursor.
abstract class SdbCursor<K extends SdbKey, V extends SdbValue> {}

/// Base for SdbOpenCursorImpl and SdbIndexOpenCursorImpl
abstract class SdbRawOpenBursorBase {
  /// Create an open cursor implementation.
  SdbRawOpenBursorBase({
    required this.offset,
    required this.limit,
    required this.idbStream,
    required this.codec,
    required this.filter,
  });

  /// Limit
  final int? offset;

  /// Offset
  final int? limit;

  /// Filter
  final SdbFilter? filter;

  /// The underlying idb stream.
  final Stream<idb.IdbCursorWithValue> idbStream;

  /// Codec to us
  final SdbCodec codec;

  /// Cursor subscription
  StreamSubscription? cursorSubscription;

  /// Done completer
  final doneCompleter = Completer<void>.sync();

  /// Done future
  late final done = doneCompleter.future;

  /// Rows already skipped to honour [offset].
  var offsetApplied = 0;

  /// True while [offset] rows still have to be skipped.
  ///
  /// The offset must be applied before the row is handed to the handler
  /// (which is a side effect), and after the filter, so it cannot be left to
  /// the cursor stream helper.
  bool skipForOffset() {
    if ((offset ?? 0) > offsetApplied) {
      offsetApplied++;
      return true;
    }
    return false;
  }

  /// Close the subscription
  void clean() {
    cursorSubscription?.cancel();
    if (!doneCompleter.isCompleted) {
      doneCompleter.complete();
    }
  }
}

/// SimpleDb open cursor implementation.
class SdbOpenCursorImpl<K extends SdbKey, V extends SdbValue>
    extends SdbRawOpenBursorBase
    implements SdbCursor<K, V> {
  /// Create an open cursor implementation.
  SdbOpenCursorImpl({
    required this.handler,
    required super.idbStream,
    super.offset,
    super.limit,
    super.filter,
    required super.codec,
  }) {
    cursorSubscription =
        cursorApplyFilterLimitOffset<
              idb.IdbCursorWithValue,
              SdbCursorRow<K, V>
            >(
              idbStream,
              (cursor) async {
                if (filter != null) {
                  if (!sdbCursorWithValueMatchesFilter(
                    cursor,
                    filter!,
                    codec,
                  )) {
                    return null;
                  }
                }
                if (skipForOffset()) {
                  return null;
                }
                final row = SdbCursorRowImpl<K, V>(cwv: cursor);
                var result = handler(row);
                bool doContinue;
                if (result is Future) {
                  doContinue = await result;
                } else {
                  doContinue = result;
                }
                if (!doContinue) {
                  clean();
                }
                return row;
              },
              // The offset is applied above, before the handler is called.
              limit: limit,
            )
            .listen(
              (_) {},
              onError: (Object e, StackTrace st) {
                clean();
              },
              onDone: () {
                clean();
              },
            );
  }

  /// The handler for each row.
  final SdbCursorRowHandler<K, V> handler;
}

/// SimpleDb cursor row.
abstract class SdbCursorRow<K extends SdbKey, V extends SdbValue> {
  /// Update the data at the current cursor position.
  Future<void> update(Object data);
}

/// Internal extension
extension SdbCursorRowInternalExt<K extends SdbKey, V extends SdbValue>
    on SdbCursorRow<K, V> {
  SdbCursorRowImpl<K, V> get _impl => this as SdbCursorRowImpl<K, V>;

  /// Raw idb value
  Object get rawValue => _impl.rawValue;

  /// Update raw idb value
  Future<void> updateRaw(Object data) => _impl.update(data);
}

/// SimpleDb cursor row internal implementation.
class SdbCursorRowImpl<K extends SdbKey, V extends SdbValue>
    implements SdbCursorRow<K, V> {
  /// Create a cursor row implementation.
  SdbCursorRowImpl({required idb.IdbCursorWithValue cwv})
    : key = cwv.key,
      rawValue = cwv.value,
      onUpdate = cwv.update;

  /// Create a row read without a cursor (native paged query), [update]
  /// writing [rawValue] back at its primary key.
  SdbCursorRowImpl.paged({
    required this.key,
    required this.rawValue,
    required this.onUpdate,
  });

  /// The row key (the index key for an index cursor).
  final Object key;

  /// The raw idb value.
  final Object rawValue;

  /// Writes a new raw value at this row position.
  final Future<void> Function(Object data) onUpdate;

  @override
  Future<void> update(Object data) async {
    await onUpdate(data);
  }

  @override
  String toString() => 'SdbCursorRow(${logTruncateAny(key)})';
}
