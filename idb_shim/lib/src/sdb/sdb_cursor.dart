import 'package:idb_shim/src/common/common_cursor.dart';
import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/src/sdb/sdb_filter_impl.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import '../../idb_client.dart' as idb;
import '../../sdb/sdb.dart';

/// Cursor row handler. Return true to continue, false to stop
typedef SdbCursorRowHandler<K extends SdbKey, V extends SdbValue> =
    FutureOr<bool> Function(SdbCursorRow<K, V> row);

/// SimpleDb cursor.
abstract class SdbCursor<K extends SdbKey, V extends SdbValue> {}

/// SimpleDb open cursor implementation.
class SdbOpenCursorImpl<K extends SdbKey, V extends SdbValue>
    implements SdbCursor<K, V> {
  /// The handler for each row.
  final SdbCursorRowHandler<K, V> handler;

  /// Limit
  final int? offset;

  /// Offset
  final int? limit;

  /// The underlying idb stream.
  final Stream<idb.IdbCursorWithValue> idbStream;

  StreamSubscription? _subscription;

  final _doneCompleter = Completer<void>.sync();

  /// Done future
  late final done = _doneCompleter.future;

  /// Filter
  final SdbFilter? filter;

  /// Create an open cursor implementation.
  SdbOpenCursorImpl({
    required this.handler,
    required this.idbStream,
    this.offset,
    this.limit,
    this.filter,
  }) {
    void clean() {
      _subscription?.cancel();
      if (!_doneCompleter.isCompleted) {
        _doneCompleter.complete();
      }
    }

    _subscription =
        cursorApplyFilterLimitOffset<
              idb.IdbCursorWithValue,
              SdbCursorRow<K, V>
            >(
              idbStream,
              (cursor) async {
                if (filter != null) {
                  if (!sdbCursorWithValueMatchesFilter(cursor, filter!)) {
                    return null;
                  }
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
              offset: offset,
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
  Object get rawValue => _impl.cwv.value;

  /// Update raw idb value
  Future<void> updateRaw(Object data) => _impl.update(data);
}

/// SimpleDb cursor row internal implementation.
class SdbCursorRowImpl<K extends SdbKey, V extends SdbValue>
    implements SdbCursorRow<K, V> {
  /// The underlying idb cursor with value.
  final idb.IdbCursorWithValue cwv;

  @override
  Future<void> update(Object data) async {
    await cwv.update(data);
  }

  /// Create a cursor row implementation.
  SdbCursorRowImpl({required this.cwv});

  @override
  String toString() => 'SdbCursorRow(${logTruncateAny(cwv.key)})';
}
