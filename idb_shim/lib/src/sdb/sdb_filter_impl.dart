import 'package:idb_shim/utils/idb_utils.dart' as idb;
import '../../sdb.dart';
import 'sdb_filter.dart';

SdbFilterPrv _filterPrv(SdbFilter filter) {
  return (filter as SdbFilterPrv);
}

/// Check if a record cursor row matches a filter.
bool sdbCursorWithValueMatchesFilter(
  idb.CursorWithValue cwv,
  SdbFilter filter,
  SdbCodec codec,
) {
  var filterPrv = _filterPrv(filter);
  var filterRecordPrv = SdbFilterRecordSnapshotPrv(cwv, codec);
  return filterPrv.matchesRecord(filterRecordPrv);
}
