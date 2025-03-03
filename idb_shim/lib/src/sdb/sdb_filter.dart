import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/utils/idb_utils.dart' as idb;
import 'package:sembast/sembast.dart' as sembast;
// ignore: implementation_imports
import 'package:sembast/src/filter_impl.dart' as sembast;

/// Private record snapshot for filter
class SdbFilterRecordSnapshotPrv implements SdbFilterRecordSnapshot {
  /// Cursor with value
  final idb.CursorWithValue cwv;

  /// Primary key
  Object? get primaryKey => cwv.primaryKey;

  /// Index key if any
  Object? get indexKey => cwv.key;

  /// Private record snapshot for filter
  SdbFilterRecordSnapshotPrv(this.cwv);
  @override
  Object? operator [](String field) {
    var data = cwv.value;
    if (data is Map) {
      return data[field];
    }
    return null;
  }

  @override
  sembast.RecordSnapshot<RK, RV>
  cast<RK extends Object?, RV extends Object?>() {
    throw UnimplementedError();
  }

  @override
  Object? get key => primaryKey;

  @override
  sembast.RecordRef<Object?, Object?> get ref => throw UnimplementedError();

  @override
  Object? get value => cwv.value;

  @override
  String toString() =>
      'FilterRecordSnapshot(${logTruncateAny(primaryKey)}, ${logTruncateAny(indexKey)}, ${logTruncateAny(value)})';
}

/// Extension to allow getting the primary key for index requests
extension SdbFilterRecordSnapshotExt on SdbFilterRecordSnapshot {
  /// Record primary key
  Object get primaryKey => (this as SdbFilterRecordSnapshotPrv).primaryKey!;

  /// Record index key if any
  Object get indexKey => (this as SdbFilterRecordSnapshotPrv).indexKey!;
}

/// Sdb filter
typedef SdbFilter = sembast.Filter;

/// Sdb custom filter matcher
typedef SdbFilterRecordSnapshot = sembast.RecordSnapshot<Object?, Object?>;

/// Private
typedef SdbFilterPrv = sembast.SembastFilterBase;
