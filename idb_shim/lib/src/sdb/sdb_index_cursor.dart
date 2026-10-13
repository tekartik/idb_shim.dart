import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/src/sdb/sdb_cursor.dart';
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
    SdbCursorRowUpdateValue? updateValue,
  }) {
    walk<SdbIndexCursorRowImpl<K, V, I>>(
      newRow: (cursor) => SdbIndexCursorRowImpl<K, V, I>(
        cwv: cursor,
        onUpdateValue: updateValue == null
            ? null
            : (value) => updateValue(cursor, value),
      ),
      handleRow: handler,
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

  /// Index key of the row.
  Object get indexKey => _impl.key;

  /// Primary key of the record the row points at.
  Object get primaryKey => _impl.primaryKey;

  /// Raw idb value
  Object get rawValue => _impl.rawValue;

  /// Update raw idb value
  Future<void> updateRaw(Object data) => _impl.onUpdate(data);
}

/// SimpleDb cursor row internal implementation.
class SdbIndexCursorRowImpl<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements SdbIndexCursorRow<K, V, I> {
  /// Create a cursor row implementation.
  SdbIndexCursorRowImpl({
    required idb.IdbCursorWithValue cwv,
    this.onUpdateValue,
  }) : key = cwv.key,
       primaryKey = cwv.primaryKey,
       rawValue = cwv.value,
       onUpdate = cwv.update;

  /// Create a row read without a cursor (native paged query), [update]
  /// writing [rawValue] back at its primary key.
  SdbIndexCursorRowImpl.paged({
    required this.key,
    required this.primaryKey,
    required this.rawValue,
    required this.onUpdate,
    this.onUpdateValue,
  });

  /// The row key (the index key for an index cursor).
  final Object key;

  /// The primary key of the record the row points at.
  final Object primaryKey;

  /// The raw idb value.
  final Object rawValue;

  /// Writes a new raw value at this row position.
  final Future<void> Function(Object data) onUpdate;

  /// Writes a new value (encoded, notified) at this row position, [onUpdate]
  /// is used if null.
  final Future<void> Function(Object value)? onUpdateValue;

  @override
  Future<void> update(Object data) async {
    var onUpdateValue = this.onUpdateValue;
    if (onUpdateValue != null) {
      await onUpdateValue(data);
    } else {
      await onUpdate(data);
    }
  }

  @override
  String toString() => 'SdbCursorRow(${logTruncateAny(key)})';
}
