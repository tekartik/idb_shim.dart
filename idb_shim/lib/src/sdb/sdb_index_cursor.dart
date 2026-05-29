import 'package:idb_shim/src/common/common_cursor.dart';
import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/src/sdb/sdb_cursor.dart';
import 'package:idb_shim/src/sdb/sdb_filter_impl.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import 'import_idb.dart' as idb;
import 'sdb.dart';

/// Cursor row handler. Return true to continue, false to stop
typedef SdbIndexCursorRowHandler<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
> = FutureOr<bool> Function(SdbIndexCursorRow<K, V, I> row);

/// SimpleDb cursor.
abstract class SdbIndexCursor<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
> {}

/// SimpleDb open cursor implementation.
class SdbIndexOpenCursorImpl<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    extends SdbRawOpenBursorBase
    implements SdbIndexCursor<K, V, I> {
  /// Create an open cursor implementation.
  SdbIndexOpenCursorImpl({
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
              SdbIndexCursorRow<K, V, I>
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
                final row = SdbIndexCursorRowImpl<K, V, I>(cwv: cursor);
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

  /// The handler for each row.
  final SdbIndexCursorRowHandler<K, V, I> handler;
}

/// SimpleDb cursor row.
abstract class SdbIndexCursorRow<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
> {
  /// Update the data at the current cursor position.
  Future<void> update(Object data);
}

/// Internal extension
extension SdbIndexCursorRowInternalExt<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndexCursorRow<K, V, I> {
  SdbIndexCursorRowImpl<K, V, I> get _impl =>
      this as SdbIndexCursorRowImpl<K, V, I>;

  /// Raw idb value
  Object get rawValue => _impl.cwv.value;

  /// Update raw idb value
  Future<void> updateRaw(Object data) => _impl.update(data);
}

/// SimpleDb cursor row internal implementation.
class SdbIndexCursorRowImpl<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbIndexCursorRow<K, V, I> {
  /// Create a cursor row implementation.
  SdbIndexCursorRowImpl({required this.cwv});

  /// The underlying idb cursor with value.
  final idb.IdbCursorWithValue cwv;

  @override
  Future<void> update(Object data) async {
    await cwv.update(data);
  }

  @override
  String toString() => 'SdbCursorRow(${logTruncateAny(cwv.key)})';
}
