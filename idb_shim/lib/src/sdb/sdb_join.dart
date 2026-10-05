import 'dart:math';

import 'package:idb_shim/src/common/common_join_query.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sdb/sdb_boundary_impl.dart';
import 'package:idb_shim/src/sdb/sdb_codec.dart';
import 'package:idb_shim/src/sdb/sdb_cursor.dart';
import 'package:idb_shim/src/sdb/sdb_index_cursor.dart';
import 'package:idb_shim/src/sdb/sdb_index_impl.dart';
import 'package:idb_shim/src/sdb/sdb_join_find_options.dart';
import 'package:idb_shim/src/sdb/sdb_record_snapshot_impl.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_impl.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_store_impl.dart';
import 'package:idb_shim/src/sdb/sdb_utils.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import 'import_idb.dart' as idb;
import 'sdb.dart';

/// Join row handler. Return true to continue, false to stop.
typedef SdbJoinRowHandler<
  K extends SdbKey,
  V extends SdbValue,
  JK extends SdbKey,
  JV extends SdbValue
> = FutureOr<bool> Function(SdbJoinRow<K, V, JK, JV> row);

/// Join record handler, for the methods handing out one side only. Return
/// true to continue, false to stop.
typedef SdbJoinRecordHandler<K extends SdbKey, V extends SdbValue> =
    FutureOr<bool> Function(SdbRecordSnapshot<K, V> record);

/// A row of a join iteration, see [SdbStoreRefJoinExtension.joinIterate] and
/// [SdbIndexRefJoinExtension.joinIterate].
///
/// It holds both sides of the join: the record of the iterated (source) store
/// and the record it references.
abstract class SdbJoinRow<
  K extends SdbKey,
  V extends SdbValue,
  JK extends SdbKey,
  JV extends SdbValue
> {
  /// The record of the iterated (source) store.
  ///
  /// Always there: a row exists because a source record was read.
  SdbRecordSnapshot<K, V> get record;

  /// The record [joinKey] matched.
  ///
  /// Null when [joinKey] is null or when nothing matches it — this is a left
  /// join. Use `inner: true` to drop those rows, or
  /// [SdbStoreRefJoinExtension.joinIterateJoinedRecords] to iterate the
  /// joined records themselves, which are never null. When the join goes
  /// through an index a join key can match several records: the source record
  /// then gives one row per match.
  SdbRecordSnapshot<JK, JV>? get joinedRecord;

  /// The key the joined record was looked up with.
  ///
  /// The value at the join key path of the source record, its primary key
  /// when no join key path was given, or the index key when iterating an
  /// index. Null when the source record has no value there — a source record
  /// with no join key cannot be dropped from a left join, so this stays
  /// nullable.
  ///
  /// Untyped: it is a primary key of the joined store when joining on a
  /// store, and an index key when joining on an index.
  Object? get joinKey;
}

/// Join row implementation.
class SdbJoinRowImpl<
  K extends SdbKey,
  V extends SdbValue,
  JK extends SdbKey,
  JV extends SdbValue
>
    implements SdbJoinRow<K, V, JK, JV> {
  /// Create a join row.
  SdbJoinRowImpl({required this.record, this.joinKey, this.joinedRecord});

  @override
  final SdbRecordSnapshot<K, V> record;

  @override
  final Object? joinKey;

  @override
  final SdbRecordSnapshot<JK, JV>? joinedRecord;

  @override
  String toString() => 'SdbJoinRow($record -> $joinKey: $joinedRecord)';
}

/// What a join iteration hands out, which is also what it has to read.
enum SdbJoinEmit {
  /// Both sides, as a [SdbJoinRow].
  rows,

  /// The source records, one per source record however many rows it gives.
  sourceRecords,

  /// The joined records; rows matching nothing are dropped.
  joinedRecords,

  /// Nothing, only the rows are counted.
  none;

  /// Whether the source record has to be read.
  bool get withSource => this == rows || this == sourceRecords;

  /// Whether the joined record has to be read.
  bool get withJoined => this == rows || this == joinedRecords;

  /// Whether the rows of one source record collapse into one.
  bool get collapseSource => this == sourceRecords;
}

/// Internal: what the runner hands out, before it is shaped into what the
/// caller asked for.
///
/// Both sides are nullable here: a join reading only one of them leaves the
/// other null. The public [SdbJoinRow] is only built in [SdbJoinEmit.rows],
/// where the source record is always read.
class SdbJoinEmitRow<
  K extends SdbKey,
  V extends SdbValue,
  JK extends SdbKey,
  JV extends SdbValue
> {
  /// Create an emitted row.
  SdbJoinEmitRow({this.record, this.joinKey, this.joinedRecord});

  /// The source record, null when it was not read.
  final SdbRecordSnapshot<K, V>? record;

  /// The join key.
  final Object? joinKey;

  /// The joined record, null when it was not read or matched nothing.
  final SdbRecordSnapshot<JK, JV>? joinedRecord;

  /// As a public row, the source record having been read.
  SdbJoinRow<K, V, JK, JV> asRow() => SdbJoinRowImpl<K, V, JK, JV>(
    record: record!,
    joinKey: joinKey,
    joinedRecord: joinedRecord,
  );
}

/// Internal: emitted row handler.
typedef SdbJoinEmitHandler<
  K extends SdbKey,
  V extends SdbValue,
  JK extends SdbKey,
  JV extends SdbValue
> = FutureOr<bool> Function(SdbJoinEmitRow<K, V, JK, JV> row);

/// Join methods on a store.
///
/// A join hands out one of three things, and only reads what it hands out:
/// the rows ([joinIterate], [findJoinRows]), the source records
/// ([joinIterateRecords], [findJoinRecords]) or the joined records
/// ([joinIterateJoinedRecords], [findJoinedRecords]).
/// Join methods, on any join source.
///
/// This is where a join is actually run; the extensions on a store and on an
/// index are sugar building the source for you.
///
/// A join hands out one of three things, and only reads what it hands out:
/// the rows ([joinIterate], [findJoinRows]), the source records
/// ([joinIterateRecords], [findJoinRecords]) or the joined records
/// ([joinIterateJoinedRecords], [findJoinedRecords]).
extension SdbJoinSourceExtension<
  K extends SdbKey,
  V extends SdbValue,
  SK extends SdbKey
>
    on SdbJoinSource<K, V, SK> {
  /// Run a join from this source, whatever it hands out.
  Future<void> _joinRun<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    required SdbTransactionMode? mode,
    required SdbFindOptions<SK>? options,
    required SdbJoinFindOptions? joinOptions,
    required SdbJoinEmit emit,
    required SdbJoinEmitHandler<K, V, JK, JV> onEmit,
    bool forceInner = false,
  }) {
    var opts = options ?? SdbFindOptions<SK>();
    var joinOpts = sdbJoinFindOptionsOrDefault(joinOptions);
    return SdbJoinRunner<K, V, JK, JV>(
      sourceStore: store,
      sourceIndex: index,
      target: target,
      joinKeyPath: joinKeyPath,
      mode: mode ?? SdbTransactionMode.readOnly,
      emit: emit,
      options: opts,
      joinOptions: joinOpts,
      inner: forceInner || joinOpts.inner,
      rangeOf: (codec) => idbKeyRangeFromBoundaries(codec, opts.boundaries),
      sourceBoundaries: sourceBoundariesOf(opts),
      onEmit: onEmit,
    ).run(client);
  }

  /// Iterate the records of this source, each with the record(s) it
  /// references.
  ///
  /// The order is the one of the source: primary key order for a store, index
  /// key order for an index (the rows sharing a join key are then
  /// consecutive).
  ///
  /// [target] is what the join key is matched against: a store, on its
  /// primary key (at most one record), or an index, on its index key (any
  /// number of records, a source record then giving one row per match, the
  /// way an sql join does). Build it with `authorStore.asJoinTarget` or
  /// `authorEmailIndex.asJoinTarget`.
  ///
  /// The join key is the index key for an index source, and for a store
  /// source the value at the key path of `asJoinSourceAt`, or its primary key
  /// when the source was built with `asJoinSource`.
  ///
  /// This is a left join: a record whose join key is null, or whose join key
  /// matches nothing, is still handed to [onRow] with a null
  /// [SdbJoinRow.joinedRecord]. Pass `inner: true` in a [SdbJoinFindOptions]
  /// to skip those rows.
  ///
  /// `options.offset` and `options.limit` apply to the rows handed to
  /// [onRow], i.e. after `inner` and `distinct` dropped any row, the way an
  /// sql `LIMIT` applies after the join. Its boundaries apply to the key the
  /// source is walked by.
  ///
  /// If [client] is a transaction, it must cover both stores, and its mode
  /// must match [mode] (asking for write mode on a read only transaction
  /// fails).
  ///
  /// [onRow] returns false to stop the iteration. Like in a transaction, no
  /// lengthy operation should be performed there, but the database can be
  /// accessed.
  Future<void> joinIterate<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbTransactionMode? mode,
    SdbFindOptions<SK>? options,
    SdbJoinFindOptions? joinOptions,
    required SdbJoinRowHandler<K, V, JK, JV> onRow,
  }) => _joinRun<JK, JV>(
    client,
    target: target,
    mode: mode,
    options: options,
    joinOptions: joinOptions,
    emit: SdbJoinEmit.rows,
    onEmit: (row) => onRow(row.asRow()),
  );

  /// The rows [joinIterate] would hand out, as a list.
  ///
  /// Same options; prefer [joinIterate] when the whole result does not have to
  /// be held in memory.
  Future<List<SdbJoinRow<K, V, JK, JV>>>
  findJoinRows<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbFindOptions<SK>? options,
    SdbJoinFindOptions? joinOptions,
  }) async {
    var rows = <SdbJoinRow<K, V, JK, JV>>[];
    await joinIterate<JK, JV>(
      client,
      target: target,
      options: options,
      joinOptions: joinOptions,
      onRow: (row) {
        rows.add(row);
        return true;
      },
    );
    return rows;
  }

  /// Iterate the records of this source taking part in the join, without
  /// reading the records they reference.
  ///
  /// One record per source record, however many rows it would give: joining
  /// on an index, a record matching three records is handed out once, not
  /// three times. `options.offset` and `options.limit` apply to the records
  /// handed out.
  ///
  /// With `inner: true` this is a semi join, an sql `WHERE EXISTS`: only the
  /// records whose join key matches something are handed out.
  Future<void> joinIterateRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbTransactionMode? mode,
    SdbFindOptions<SK>? options,
    SdbJoinFindOptions? joinOptions,
    required SdbJoinRecordHandler<K, V> onRecord,
  }) => _joinRun<JK, JV>(
    client,
    target: target,
    mode: mode,
    options: options,
    joinOptions: joinOptions,
    emit: SdbJoinEmit.sourceRecords,
    onEmit: (row) => onRecord(row.record!),
  );

  /// The records [joinIterateRecords] would hand out, as a list.
  Future<List<SdbRecordSnapshot<K, V>>>
  findJoinRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbFindOptions<SK>? options,
    SdbJoinFindOptions? joinOptions,
  }) async {
    var records = <SdbRecordSnapshot<K, V>>[];
    await joinIterateRecords<JK, JV>(
      client,
      target: target,
      options: options,
      joinOptions: joinOptions,
      onRecord: (record) {
        records.add(record);
        return true;
      },
    );
    return records;
  }

  /// Iterate the records this source references, without reading the source
  /// records.
  ///
  /// The rows matching nothing are dropped (the iteration is always inner,
  /// there is no record to hand out otherwise), so the records handed out are
  /// never null. A source record matching several records gives one record
  /// per match.
  ///
  /// Pass `distinct: true` in a [SdbJoinFindOptions] to hand out the records
  /// of each join key once, which is how you read the records actually
  /// referenced by this source.
  Future<void> joinIterateJoinedRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbTransactionMode? mode,
    SdbFindOptions<SK>? options,
    SdbJoinFindOptions? joinOptions,
    required SdbJoinRecordHandler<JK, JV> onRecord,
  }) => _joinRun<JK, JV>(
    client,
    target: target,
    mode: mode,
    options: options,
    joinOptions: joinOptions,
    emit: SdbJoinEmit.joinedRecords,
    forceInner: true,
    onEmit: (row) {
      var joinedRecord = row.joinedRecord;
      // Always inner, so there is one; never crash if an implementation
      // hands out a row without it.
      return joinedRecord == null ? true : onRecord(joinedRecord);
    },
  );

  /// The records [joinIterateJoinedRecords] would hand out, as a list.
  Future<List<SdbRecordSnapshot<JK, JV>>>
  findJoinedRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbFindOptions<SK>? options,
    SdbJoinFindOptions? joinOptions,
  }) async {
    var records = <SdbRecordSnapshot<JK, JV>>[];
    await joinIterateJoinedRecords<JK, JV>(
      client,
      target: target,
      options: options,
      joinOptions: joinOptions,
      onRecord: (record) {
        records.add(record);
        return true;
      },
    );
    return records;
  }

  /// The number of rows [joinIterate] would hand out.
  ///
  /// Without `distinct` nor `inner`, and joining on a store (at most one
  /// match per record), every record of the source gives one row, so this is
  /// the record count. Otherwise rows are added or dropped in a way only a
  /// scan can tell, so the join is run, reading as little as it can (neither
  /// side is handed out).
  Future<int> joinCount<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbFindOptions<SK>? options,
    SdbJoinFindOptions? joinOptions,
  }) async {
    var joinOpts = sdbJoinFindOptionsOrDefault(joinOptions);
    if (!joinOpts.distinct &&
        !joinOpts.inner &&
        target.index == null &&
        options?.offset == null &&
        options?.limit == null) {
      return countRecords(client, options);
    }
    var rowCount = 0;
    await _joinRun<JK, JV>(
      client,
      target: target,
      mode: null,
      options: options,
      joinOptions: joinOptions,
      emit: SdbJoinEmit.none,
      onEmit: (row) {
        rowCount++;
        return true;
      },
    );
    return rowCount;
  }
}

/// Join methods on a store, sugar over `asJoinSource`/`asJoinSourceAt`.
///
/// Every method takes the same options as its [SdbJoinSourceExtension]
/// counterpart, plus the [joinKeyPath] the join key is read at (null for the
/// primary key of the source record, which is what a one to many join from
/// the parent side needs).
///
/// Prefer the index extension when the join key path is indexed: it says so
/// in the API, and an implementation able to join natively then reads the
/// join key straight from the index.
extension SdbStoreRefJoinExtension<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// This store as a join source reading the join key at [joinKeyPath].
  SdbJoinSource<K, V, K> _sourceAt(String? joinKeyPath) =>
      joinKeyPath == null ? asJoinSource : asJoinSourceAt(joinKeyPath);

  /// See [SdbJoinSourceExtension.joinIterate].
  Future<void> joinIterate<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    String? joinKeyPath,
    SdbTransactionMode? mode,
    SdbFindOptions<K>? options,
    SdbJoinFindOptions? joinOptions,
    required SdbJoinRowHandler<K, V, JK, JV> onRow,
  }) => _sourceAt(joinKeyPath).joinIterate<JK, JV>(
    client,
    target: target,
    mode: mode,
    options: options,
    joinOptions: joinOptions,
    onRow: onRow,
  );

  /// See [SdbJoinSourceExtension.findJoinRows].
  Future<List<SdbJoinRow<K, V, JK, JV>>>
  findJoinRows<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    String? joinKeyPath,
    SdbFindOptions<K>? options,
    SdbJoinFindOptions? joinOptions,
  }) => _sourceAt(joinKeyPath).findJoinRows<JK, JV>(
    client,
    target: target,
    options: options,
    joinOptions: joinOptions,
  );

  /// See [SdbJoinSourceExtension.joinIterateRecords].
  Future<void> joinIterateRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    String? joinKeyPath,
    SdbTransactionMode? mode,
    SdbFindOptions<K>? options,
    SdbJoinFindOptions? joinOptions,
    required SdbJoinRecordHandler<K, V> onRecord,
  }) => _sourceAt(joinKeyPath).joinIterateRecords<JK, JV>(
    client,
    target: target,
    mode: mode,
    options: options,
    joinOptions: joinOptions,
    onRecord: onRecord,
  );

  /// See [SdbJoinSourceExtension.findJoinRecords].
  Future<List<SdbRecordSnapshot<K, V>>>
  findJoinRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    String? joinKeyPath,
    SdbFindOptions<K>? options,
    SdbJoinFindOptions? joinOptions,
  }) => _sourceAt(joinKeyPath).findJoinRecords<JK, JV>(
    client,
    target: target,
    options: options,
    joinOptions: joinOptions,
  );

  /// See [SdbJoinSourceExtension.joinIterateJoinedRecords].
  Future<void> joinIterateJoinedRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    String? joinKeyPath,
    SdbTransactionMode? mode,
    SdbFindOptions<K>? options,
    SdbJoinFindOptions? joinOptions,
    required SdbJoinRecordHandler<JK, JV> onRecord,
  }) => _sourceAt(joinKeyPath).joinIterateJoinedRecords<JK, JV>(
    client,
    target: target,
    mode: mode,
    options: options,
    joinOptions: joinOptions,
    onRecord: onRecord,
  );

  /// See [SdbJoinSourceExtension.findJoinedRecords].
  Future<List<SdbRecordSnapshot<JK, JV>>>
  findJoinedRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    String? joinKeyPath,
    SdbFindOptions<K>? options,
    SdbJoinFindOptions? joinOptions,
  }) => _sourceAt(joinKeyPath).findJoinedRecords<JK, JV>(
    client,
    target: target,
    options: options,
    joinOptions: joinOptions,
  );

  /// See [SdbJoinSourceExtension.joinCount].
  Future<int> joinCount<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    String? joinKeyPath,
    SdbFindOptions<K>? options,
    SdbJoinFindOptions? joinOptions,
  }) => _sourceAt(joinKeyPath).joinCount<JK, JV>(
    client,
    target: target,
    options: options,
    joinOptions: joinOptions,
  );
}

/// Join methods on an index, sugar over `asJoinSource`.
///
/// This is the shape to prefer: the join key is the index key, so it is read
/// straight from the index instead of out of every stored value, which is
/// what lets an implementation able to join natively do it efficiently.
///
/// Every method takes the same options as its [SdbJoinSourceExtension]
/// counterpart; there is no key path, and `options` applies to the index key.
extension SdbIndexRefJoinExtension<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    on SdbIndexRef<K, V, I> {
  /// See [SdbJoinSourceExtension.joinIterate].
  Future<void> joinIterate<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbTransactionMode? mode,
    SdbFindOptions<I>? options,
    SdbJoinFindOptions? joinOptions,
    required SdbJoinRowHandler<K, V, JK, JV> onRow,
  }) => asJoinSource.joinIterate<JK, JV>(
    client,
    target: target,
    mode: mode,
    options: options,
    joinOptions: joinOptions,
    onRow: onRow,
  );

  /// See [SdbJoinSourceExtension.findJoinRows].
  Future<List<SdbJoinRow<K, V, JK, JV>>>
  findJoinRows<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbFindOptions<I>? options,
    SdbJoinFindOptions? joinOptions,
  }) => asJoinSource.findJoinRows<JK, JV>(
    client,
    target: target,
    options: options,
    joinOptions: joinOptions,
  );

  /// See [SdbJoinSourceExtension.joinIterateRecords].
  Future<void> joinIterateRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbTransactionMode? mode,
    SdbFindOptions<I>? options,
    SdbJoinFindOptions? joinOptions,
    required SdbJoinRecordHandler<K, V> onRecord,
  }) => asJoinSource.joinIterateRecords<JK, JV>(
    client,
    target: target,
    mode: mode,
    options: options,
    joinOptions: joinOptions,
    onRecord: onRecord,
  );

  /// See [SdbJoinSourceExtension.findJoinRecords].
  Future<List<SdbRecordSnapshot<K, V>>>
  findJoinRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbFindOptions<I>? options,
    SdbJoinFindOptions? joinOptions,
  }) => asJoinSource.findJoinRecords<JK, JV>(
    client,
    target: target,
    options: options,
    joinOptions: joinOptions,
  );

  /// See [SdbJoinSourceExtension.joinIterateJoinedRecords].
  Future<void> joinIterateJoinedRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbTransactionMode? mode,
    SdbFindOptions<I>? options,
    SdbJoinFindOptions? joinOptions,
    required SdbJoinRecordHandler<JK, JV> onRecord,
  }) => asJoinSource.joinIterateJoinedRecords<JK, JV>(
    client,
    target: target,
    mode: mode,
    options: options,
    joinOptions: joinOptions,
    onRecord: onRecord,
  );

  /// See [SdbJoinSourceExtension.findJoinedRecords].
  Future<List<SdbRecordSnapshot<JK, JV>>>
  findJoinedRecords<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbFindOptions<I>? options,
    SdbJoinFindOptions? joinOptions,
  }) => asJoinSource.findJoinedRecords<JK, JV>(
    client,
    target: target,
    options: options,
    joinOptions: joinOptions,
  );

  /// See [SdbJoinSourceExtension.joinCount].
  Future<int> joinCount<JK extends SdbKey, JV extends SdbValue>(
    SdbClient client, {
    required SdbJoinTarget<JK, JV> target,
    SdbFindOptions<I>? options,
    SdbJoinFindOptions? joinOptions,
  }) => asJoinSource.joinCount<JK, JV>(
    client,
    target: target,
    options: options,
    joinOptions: joinOptions,
  );
}

/// Runs one join iteration.
///
/// Either side can be a store or an index, so the shape of the join is held
/// here rather than in the extension the caller went through.
class SdbJoinRunner<
  K extends SdbKey,
  V extends SdbValue,
  JK extends SdbKey,
  JV extends SdbValue
> {
  /// Create a runner.
  SdbJoinRunner({
    required this.sourceStore,
    required this.sourceIndex,
    required this.target,
    required this.joinKeyPath,
    required this.mode,
    required this.emit,
    required this.options,
    required this.joinOptions,
    required this.inner,
    required this.rangeOf,
    required this.sourceBoundaries,
    required this.onEmit,
  });

  /// The iterated store.
  final SdbStoreRef<K, V> sourceStore;

  /// The iterated index, null to iterate [sourceStore] itself.
  final SdbIndexRef<K, V, SdbIndexKey>? sourceIndex;

  /// What the join key is matched against: a store or an index, exactly one
  /// of the two by construction.
  final SdbJoinTarget<JK, JV> target;

  /// The joined index, null when matching on the primary key of the target
  /// store.
  SdbIndexRef<JK, JV, SdbIndexKey>? get targetIndex => target.index;

  /// Field path of the join key, null for the key the source iterates by.
  final String? joinKeyPath;

  /// Transaction mode.
  final SdbTransactionMode mode;

  /// What the join hands out, which is also what it has to read.
  final SdbJoinEmit emit;

  /// What is read on the iterated side, shared with the methods that built
  /// this runner.
  final SdbFindOptions<SdbKey> options;

  /// How the two sides are joined, shared with the methods that built this
  /// runner.
  final SdbJoinFindOptions joinOptions;

  /// Whether the rows with no joined record are dropped.
  ///
  /// [SdbJoinFindOptions.inner], forced on when the join hands out the joined
  /// records (there is nothing to hand out otherwise).
  final bool inner;

  /// Whether the source record has to be read.
  bool get withSource => emit.withSource;

  /// Whether the joined record has to be read.
  bool get withJoined => emit.withJoined;

  /// Whether the rows of one source record collapse into one.
  bool get collapseSource => emit.collapseSource;

  /// Whether only the first source record of each join key is expanded.
  bool get distinct => joinOptions.distinct;

  /// In memory filter on the source records.
  SdbFilter? get filter => options.filter;

  /// Rows to skip, applied to the rows handed out.
  int? get offset => options.offset;

  /// Rows to hand out at most.
  int? get limit => options.limit;

  /// Source iteration order.
  bool? get descending => options.descending;

  /// Rows read per query through a native join.
  int get chunkSize => joinOptions.chunkSize;

  /// The source range, resolved once the codec is known.
  final idb.KeyRange? Function(SdbCodec codec) rangeOf;

  /// Boundaries on the source primary key, null when iterating an index (the
  /// boundaries then apply to the index key and go through [rangeOf]).
  final SdbBoundaries<K>? sourceBoundaries;

  /// The emitted row handler.
  final SdbJoinEmitHandler<K, V, JK, JV> onEmit;

  /// The store holding the joined records.
  SdbStoreRef<JK, JV> get _joinedStore => target.store;

  /// Join keys already expanded, for [distinct].
  Set<Object?>? _seen;

  /// Rows still to skip to honour [offset].
  var _skip = 0;

  /// Rows handed out so far.
  var _emitted = 0;

  /// Limit applied in dart, null when it is pushed down.
  int? _emitLimit;

  /// Run the join with [client], a database or a transaction covering both
  /// stores.
  Future<void> run(SdbClient client) async {
    var stores = <SdbStoreRef>[sourceStore, _joinedStore];
    await _autoJoinTxn(client, stores, mode, (txn) async {
      _reset();

      var codec = txn.codec;
      var range = rangeOf(codec);
      var direction = descendingToIdbDirection(descending);

      var native = filter == null
          ? idbJoinQuerySupportOrNull(_idbSourceOf(txn))
          : null;
      if (native != null) {
        // [distinct] is applied in dart (an sql `GROUP BY` would not tell
        // which source row was kept), so the offset and the limit cannot be
        // pushed down with it. Neither can they when the rows of one source
        // record collapse into one and a native row is not an emitted unit.
        var pushDown = !distinct && !(collapseSource && targetIndex != null);
        if (!pushDown) {
          _skip = offset ?? 0;
          _emitLimit = limit;
        }
        var done = await _runNative(
          native,
          codec: codec,
          range: range,
          direction: direction,
          offset: pushDown ? offset : null,
          limit: pushDown ? limit : null,
        );
        if (done) {
          return;
        }
        // The implementation could not resolve this join, fall back to
        // reading the joined records one by one. Nothing was handed out yet.
        _reset();
      }

      await _runGeneric(txn, codec: codec);
    });
  }

  void _reset() {
    _seen = distinct ? <Object?>{} : null;
    _skip = 0;
    _emitted = 0;
    _emitLimit = null;
    _lastSourceKey = null;
    _skippingSource = false;
  }

  /// The idb object store or index the join is iterated from, null when the
  /// implementation is not idb based (no native join then).
  Object? _idbSourceOf(SdbTransaction txn) {
    var txnStore = txn.store<K, V>(sourceStore);
    if (txnStore is! SdbTransactionStoreRefImpl<K, V>) {
      return null;
    }
    var idbObjectStore = txnStore.idbObjectStore;
    var sourceIndex = this.sourceIndex;
    if (sourceIndex == null) {
      return idbObjectStore;
    }
    return idbObjectStore.index(sourceIndex.name);
  }

  /// Hand a row to [onRow], applying the offset and the limit. Returns false
  /// to stop the iteration.
  Future<bool> _emitRow({
    required Object? joinKey,
    SdbRecordSnapshot<K, V>? record,
    SdbRecordSnapshot<JK, JV>? joinedRecord,
  }) async {
    if (_skip > 0) {
      _skip--;
      return true;
    }
    var result = onEmit(
      SdbJoinEmitRow<K, V, JK, JV>(
        record: record,
        joinKey: joinKey,
        joinedRecord: joinedRecord,
      ),
    );
    var doContinue = result is Future<bool> ? await result : result;
    _emitted++;
    if (!doContinue) {
      return false;
    }
    var emitLimit = _emitLimit;
    return emitLimit == null || _emitted < emitLimit;
  }

  /// Hand out the rows of one source record, applying [distinct] and [inner].
  ///
  /// [matchCount] is how many records the join key matched, which is what
  /// decides the number of rows; [joined] holds them when they were read, and
  /// is null when the caller did not ask for the joined side.
  Future<bool> _emitSource({
    required Object? joinKey,
    required int matchCount,
    List<SdbRecordSnapshot<JK, JV>>? joined,
    SdbRecordSnapshot<K, V>? record,
  }) async {
    var seen = _seen;
    if (seen != null && !seen.add(joinKey)) {
      return true;
    }
    if (matchCount == 0) {
      if (inner) {
        return true;
      }
      return _emitRow(joinKey: joinKey, record: record);
    }
    if (collapseSource) {
      // The source record is handed out once however many records it matched.
      return _emitRow(joinKey: joinKey, record: record);
    }
    for (var i = 0; i < matchCount; i++) {
      var doContinue = await _emitRow(
        joinKey: joinKey,
        record: record,
        joinedRecord: joined?[i],
      );
      if (!doContinue) {
        return false;
      }
    }
    return true;
  }

  /// Walk the source, reading the joined records one by one.
  Future<void> _runGeneric(
    SdbTransaction txn, {
    required SdbCodec codec,
  }) async {
    // [inner] and [distinct] drop rows, and a join through an index adds
    // some, so the offset and the limit can only be pushed down to the scan
    // when the rows handed out match the source records one for one.
    // Collapsing gives that back: one source record is then one row again,
    // however many records it matched.
    var pushDown =
        !distinct && !inner && (targetIndex == null || collapseSource);
    if (!pushDown) {
      _skip = offset ?? 0;
      _emitLimit = limit;
    }
    var scanOffset = pushDown ? offset : null;
    var scanLimit = pushDown ? limit : null;

    /// Matches already read, by join key: a join key is very often shared by
    /// several source records.
    var cache = <Object, _SdbJoinMatches<JK, JV>>{};
    var lookup = _lookupOf(txn);
    // Joining on a store matches at most one record, so when neither the
    // caller nor `inner` needs it the row count is the same either way and
    // nothing has to be read. Joining on an index can match any number of
    // records, which changes the row count, so the match is needed — unless
    // the rows of one source record collapse into one, which makes the count
    // irrelevant again.
    var needsMatch =
        withJoined || inner || (targetIndex != null && !collapseSource);

    Future<bool> handleSource(K key, V value, Object? joinKey) async {
      _SdbJoinMatches<JK, JV>? matches;
      if (joinKey != null && needsMatch) {
        matches = cache[joinKey] ??= await lookup(joinKey);
      }
      return _emitSource(
        joinKey: joinKey,
        matchCount: matches?.count ?? 0,
        joined: withJoined ? matches?.records : null,
        record: withSource
            ? SdbRecordSnapshotImpl<K, V>(sourceStore.record(key), value)
            : null,
      );
    }

    var sourceIndex = this.sourceIndex;
    if (sourceIndex != null) {
      // The boundaries apply to the index key.
      await sourceIndex.impl
          .txnIndexInterface(txn)
          .iterateImpl(
            options: SdbFindOptions<SdbKey>(
              boundaries: options.boundaries,
              filter: filter,
              offset: scanOffset,
              limit: scanLimit,
              descending: descending,
            ),
            handler: (row) async {
              return handleSource(
                row.primaryKey as K,
                codec.decode<V>(row.rawValue),
                // The index key is the join key, as stored: a join key is a
                // plain key, looked up as is on the joined side.
                row.indexKey,
              );
            },
          );
      return;
    }

    var joinKeyPath = this.joinKeyPath;
    await sourceStore.iterate(
      txn,
      mode: mode,
      options: SdbFindOptions<K>(
        filter: filter,
        offset: scanOffset,
        limit: scanLimit,
        descending: descending,
        boundaries: sourceBoundaries,
      ),
      onRow: (row) async {
        var rowImpl = row as SdbCursorRowImpl<K, V>;
        var key = rowImpl.key as K;
        var value = codec.decode<V>(rowImpl.rawValue);
        return handleSource(
          key,
          value,
          joinKeyPath == null ? key : _joinKeyOf(value, joinKeyPath),
        );
      },
    );
  }

  /// Reads what a join key matches.
  ///
  /// Only the count is read when the caller does not want the joined side.
  ///
  /// An index lookup goes through the cursor-less reads of the transaction
  /// index (`getAllKeys` on idb) rather than through a cursor: this runs
  /// inside the handler of the cursor walking the source, and an
  /// implementation serialising its operations (sembast does) deadlocks on a
  /// second cursor opened while the first one is being advanced.
  Future<_SdbJoinMatches<JK, JV>> Function(Object joinKey) _lookupOf(
    SdbTransaction txn,
  ) {
    var joinedStore = _joinedStore;
    var targetIndex = this.targetIndex;
    if (targetIndex != null) {
      var txnIndex = targetIndex.impl.txnIndexInterface(txn);
      if (!withJoined) {
        return (joinKey) async {
          var keys = await txnIndex.getKeysImpl(joinKey);
          return _SdbJoinMatches<JK, JV>(keys.length, null);
        };
      }
      return (joinKey) async {
        var snapshots = await txnIndex.getRecordsImpl(joinKey);
        var records = snapshots
            .map(
              (snapshot) => SdbRecordSnapshotImpl<JK, JV>(
                joinedStore.record(snapshot.key),
                snapshot.value,
              ),
            )
            .toList();
        return _SdbJoinMatches<JK, JV>(records.length, records);
      };
    }
    var txnJoinStore = txn.store<JK, JV>(joinedStore);
    if (!withJoined) {
      return (joinKey) async {
        var exists = await txnJoinStore.exists(joinKey as JK);
        return _SdbJoinMatches<JK, JV>(exists ? 1 : 0, null);
      };
    }
    return (joinKey) async {
      var record = await txnJoinStore.getRecord(joinKey as JK);
      return record == null
          ? _SdbJoinMatches<JK, JV>(0, null)
          : _SdbJoinMatches<JK, JV>(1, [record]);
    };
  }

  /// Resolve the join through [native], chunk by chunk.
  ///
  /// Returns false when [native] cannot resolve this join, nothing having been
  /// handed out then.
  Future<bool> _runNative(
    IdbJoinQuerySupport native, {
    required SdbCodec codec,
    required idb.KeyRange? range,
    required String? direction,
    required int? offset,
    required int? limit,
  }) async {
    var joinedStore = _joinedStore;
    var start = offset ?? 0;
    var read = 0;
    while (true) {
      var wanted = limit == null ? chunkSize : min(chunkSize, limit - read);
      if (wanted <= 0) {
        return true;
      }
      var rows = await native.joinedRowList(
        joinStoreName: joinedStore.name,
        joinIndexName: targetIndex?.name,
        joinKeyPath: joinKeyPath,
        range: range,
        direction: direction,
        offset: start + read,
        limit: wanted,
        inner: inner,
        withValue: withSource,
        withJoinedValue: withJoined,
      );
      if (rows == null) {
        // Not supported, and read == 0: nothing was handed out.
        return read > 0;
      }
      if (rows.isEmpty) {
        return true;
      }
      for (var row in rows) {
        read++;
        var rawValue = row.value;
        var rawJoinedValue = row.joinedValue;
        var joinedPrimaryKey = row.joinedPrimaryKey;
        // A native join hands out its rows already flattened: a source record
        // matching several records comes back as that many consecutive rows.
        // [distinct] works on source records, so it only applies to the first
        // row of each.
        var newSource = !_sameKey(row.primaryKey, _lastSourceKey);
        if (newSource) {
          _lastSourceKey = row.primaryKey;
          var seen = _seen;
          _skippingSource = seen != null && !seen.add(row.joinKey);
        } else if (collapseSource) {
          // The source record was handed out on its first row.
          continue;
        }
        if (_skippingSource) {
          continue;
        }
        var doContinue = await _emitRowOfNative(
          joinKey: row.joinKey,
          joinedPrimaryKey: joinedPrimaryKey,
          rawJoinedValue: rawJoinedValue,
          codec: codec,
          joinedStore: joinedStore,
          record: rawValue == null
              ? null
              : SdbRecordSnapshotImpl<K, V>(
                  sourceStore.record(row.primaryKey as K),
                  codec.decode<V>(rawValue),
                ),
        );
        if (!doContinue) {
          return true;
        }
      }
      if (rows.length < wanted) {
        // Short chunk, the end is reached.
        return true;
      }
    }
  }

  /// Primary key of the source record of the last native row, to tell when a
  /// new source record starts.
  Object? _lastSourceKey;

  /// Whether the rows of the current source record are being skipped, for
  /// [distinct].
  var _skippingSource = false;

  /// Hand out one already flattened native row.
  Future<bool> _emitRowOfNative({
    required Object? joinKey,
    required Object? joinedPrimaryKey,
    required Object? rawJoinedValue,
    required SdbCodec codec,
    required SdbStoreRef<JK, JV> joinedStore,
    SdbRecordSnapshot<K, V>? record,
  }) async {
    if (joinedPrimaryKey == null) {
      // Nothing matched: `inner` would have dropped the row already, so this
      // is the null side of a left join.
      if (inner) {
        return true;
      }
      return _emitRow(joinKey: joinKey, record: record);
    }
    if (collapseSource) {
      // The source record is handed out once, the joined side is not read.
      return _emitRow(joinKey: joinKey, record: record);
    }
    return _emitRow(
      joinKey: joinKey,
      record: record,
      joinedRecord: (withJoined && rawJoinedValue != null)
          ? SdbRecordSnapshotImpl<JK, JV>(
              joinedStore.record(joinedPrimaryKey as JK),
              codec.decode<JV>(rawJoinedValue),
            )
          : null,
    );
  }
}

/// What a join key matched, see [SdbJoinRunner].
class _SdbJoinMatches<JK extends SdbKey, JV extends SdbValue> {
  /// Create matches.
  _SdbJoinMatches(this.count, this.records);

  /// How many records matched.
  final int count;

  /// The matched records, null when only the count was read.
  final List<SdbRecordSnapshot<JK, JV>>? records;
}

/// True when [key1] and [key2] are the same record key, a composite key being
/// a list.
bool _sameKey(Object? key1, Object? key2) {
  if (key1 is List && key2 is List) {
    return valueListEquals(key1, key2);
  }
  return key1 == key2;
}

/// Run [fn] in a transaction covering [stores], reusing [client] when it
/// already is a transaction.
Future<void> _autoJoinTxn(
  SdbClient client,
  List<SdbStoreRef> stores,
  SdbTransactionMode mode,
  Future<void> Function(SdbTransaction txn) fn,
) async {
  if (client is SdbTransaction) {
    return await fn(client);
  } else if (client is SdbDatabase) {
    return await client.inStoresTransaction(stores, mode, (txn) => fn(txn));
  } else {
    throw ArgumentError('Invalid client type: ${client.runtimeType}');
  }
}

/// The value at [joinKeyPath] in [value], null when there is none.
Object? _joinKeyOf(Object value, String joinKeyPath) {
  if (value is Map) {
    return value.getFieldValue<Object>(joinKeyPath);
  }
  return null;
}
