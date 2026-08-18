import 'package:idb_shim/src/utils/cursor_utils.dart';

/// Internal: native paged query support.
///
/// Implemented by an [ObjectStore] or an [Index] implementation able to apply
/// an offset and a limit natively (typically an sql `LIMIT`/`OFFSET`) instead
/// of walking a cursor row by row. An implementation reading its rows in one
/// go (sql based ones) would otherwise read the whole store on every paged
/// query, the offset and the limit being applied in dart afterwards.
///
/// This is only used by the sdb layer, and only when no filter is involved
/// (a filter is applied in dart, so the limit cannot be pushed down). It is
/// deliberately not part of the public idb API: it carries no guarantee and
/// can change at any time.
///
/// The returned values are handed out as is, an implementation must return
/// values that are not shared with its internal state (i.e. decoded or
/// cloned).
abstract class IdbPagedQuerySupport {
  /// Rows, value included, of [range] in [direction], skipping the first
  /// [offset] rows and returning at most [limit] rows.
  ///
  /// [direction] is [idbDirectionNext] or [idbDirectionPrev], null meaning
  /// [idbDirectionNext].
  Future<List<IdbCursorRow>> pagedRowList({
    KeyRange? range,
    String? direction,
    int? offset,
    int? limit,
  });

  /// Same as [pagedRowList], keys only.
  Future<List<IdbKeyCursorRow>> pagedKeyRowList({
    KeyRange? range,
    String? direction,
    int? offset,
    int? limit,
  });

  /// Write [value] at [primaryKey], what updating the row at the current
  /// position of a cursor does.
  ///
  /// Needed to iterate through [pagedRowList]: the rows are read without a
  /// cursor, so there is no cursor to update.
  Future<void> pagedRowUpdate(Object primaryKey, Object value);
}

/// Cursor row built without a cursor, for [IdbPagedQuerySupport]
/// implementations.
class IdbPagedCursorRow extends IdbCursorRow {
  /// Create a row from its [key], [primaryKey] and [value].
  IdbPagedCursorRow(super.key, super.primaryKey, super.value);
}

/// The [IdbPagedQuerySupport] of [object], null when the implementation
/// cannot page natively (the caller must then walk a cursor).
IdbPagedQuerySupport? idbPagedQuerySupportOrNull(Object? object) =>
    object is IdbPagedQuerySupport ? object : null;
