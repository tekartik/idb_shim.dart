import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/utils/idb_utils.dart' as idb;
import 'package:sembast/sembast.dart' as sembast;
// ignore: implementation_imports
import 'package:sembast/src/api/protected/filter.dart' as sembast;

import 'sdb_codec.dart';

/// Private record snapshot for filter
class SdbFilterRecordSnapshotPrv implements SdbFilterRecordSnapshot {
  /// From an idb cursor, the value is decoded lazily.
  SdbFilterRecordSnapshotPrv(idb.CursorWithValue cwv, SdbCodec codec)
    : primaryKey = cwv.primaryKey,
      indexKey = cwv.key,
      _rawValue = cwv.value,
      _codec = codec;

  /// From an already decoded [value], for non idb implementations.
  /// [indexKey] defaults to [primaryKey] (store query).
  SdbFilterRecordSnapshotPrv.decoded({
    required this.primaryKey,
    Object? indexKey,
    required Object? value,
  }) : indexKey = indexKey ?? primaryKey,
       _rawValue = null,
       _codec = null,
       _valueDecoded = true {
    _value = value;
  }

  final SdbCodec? _codec;
  final Object? _rawValue;
  Object? _value;
  bool _valueDecoded = false;

  /// Primary key
  final Object? primaryKey;

  /// Index key if any
  final Object? indexKey;
  @override
  Object? operator [](String field) {
    var data = value;
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

  /// Can be null for cursor without values
  @override
  Object? get value {
    if (!_valueDecoded) {
      _valueDecoded = true;
      var rawValue = _rawValue;
      _value = rawValue == null ? null : _codec!.decode<Object>(rawValue);
    }
    return _value;
  }

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
typedef SdbFilterPrv = sembast.SembastFilter;
