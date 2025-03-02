import 'package:idb_shim/utils/idb_utils.dart' as idb;
// ignore: implementation_imports
import 'sdb_filter.dart';

SdbFilterPrv _filterPrv(SdbFilter filter) {
  return (filter as SdbFilterPrv);
}

/// Check if a record cursor row matches a filter.
bool sdbRecordRowMatchesFilter(idb.CursorRow row, SdbFilter filter) {
  var filterPrv = _filterPrv(filter);
  var filterRecordPrv = SdbFilterRecordSnapshotPrv(row);
  return filterPrv.matchesRecord(filterRecordPrv);
}

/// Private extension to apply filter, offset and limit to a list of cursor rows.
extension SdbCursorRowListPrvExt on List<idb.CursorRow> {
  /// Apply filter, offset and limit.
  void applyFilterOffsetAndLimit(
    SdbFilter filter, {
    required int? limit,
    required int? offset,
  }) {
    removeWhere((row) => !sdbRecordRowMatchesFilter(row, filter));
    if (offset != null) {
      removeRange(0, offset);
    }
    if (limit != null && limit < length) {
      removeRange(limit, length);
    }
  }
}
