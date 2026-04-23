import 'package:idb_shim/src/common/common_cursor.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import '../../idb_client.dart' as idb;
import '../../sdb/sdb.dart';

/// Cursor row handler.
typedef SdbCursorRowHandler<K extends SdbKey> =
    FutureOr<void> Function(SdbCursorRow<K> row);

/// SimpleDb cursor.
abstract class SdbCursor<K extends SdbKey, V extends SdbValue> {}

/// SimpleDb open cursor implementation.
class SdbOpenCursorImpl<K extends SdbKey, V extends SdbValue>
    implements SdbCursor<K, V> {
  /// The handler for each row.
  final SdbCursorRowHandler<K> handler;

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

  /// Create an open cursor implementation.
  SdbOpenCursorImpl({
    required this.handler,
    required this.idbStream,
    this.offset,
    this.limit,
  }) {
    void clean() {
      _subscription?.cancel();
      if (!_doneCompleter.isCompleted) {
        _doneCompleter.complete();
      }
    }

    _subscription =
        cursorApplyFilterLimitOffset<idb.IdbCursorWithValue, SdbCursorRow<K>>(
          idbStream,
          (cursor) async {
            final row = SdbCursorRowImpl<K>(cwv: cursor);
            var result = handler(row);
            if (result is Future) {
              await result;
            }
            return row;
          },
          offset: offset,
          limit: limit,
        ).listen(
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
abstract class SdbCursorRow<K extends SdbKey> {
  /// Update the data at the current cursor position.
  Future<void> update(Object data);
}

/// SimpleDb cursor row internal implementation.
class SdbCursorRowImpl<K extends SdbKey> implements SdbCursorRow<K> {
  /// The underlying idb cursor with value.
  final idb.IdbCursorWithValue cwv;

  @override
  Future<void> update(Object data) async {
    await cwv.update(data);
  }

  /// Create a cursor row implementation.
  SdbCursorRowImpl({required this.cwv});
}
