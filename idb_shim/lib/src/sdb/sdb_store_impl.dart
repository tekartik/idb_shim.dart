import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/sdb/sdb_key_utils.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:meta/meta.dart';

import 'sdb.dart';
import 'sdb_client.dart';
import 'sdb_database.dart';
import 'sdb_transaction.dart';

/// Store reference internal extension.
extension SdbStoreRefInternalExtension<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// Store reference implementation.
  SdbStoreRefImpl<K, V> get impl => this as SdbStoreRefImpl<K, V>;
}

/// Store reference implementation.
extension SdbStoreRefDbInternalExtension<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// Do not use yet
  @internal
  @Deprecated('Use iterate instead')
  /// if client is a transaction it must match the transaction mode
  /// requiring write mode if the transaction is ready only will fail
  Future<void> handleRecords(
    SdbClient client, {
    SdbTransactionMode? mode,
    SdbFindOptions<K>? options,
    required SdbCursorRowHandler<K, V> handler,
  }) async {
    await impl.clientIterateImpl(
      client,
      mode: mode ?? SdbTransactionMode.readOnly,
      options: options ?? SdbFindOptions(),
      handler: handler,
    );
  }
}

/// Store reference implementation.
extension SdbStoreRefDbExtension<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// Add a single record.

  Future<K> add(SdbClient client, V value) =>
      client.interface.sdbAddImpl<K, V>(this, value);

  /// Put a single record (when using inline keys)
  Future<K> put(SdbClient client, V value) => impl.putImpl(client, value);

  /// if client is a transaction it must match the transaction mode
  /// requiring write mode if the transaction is ready only will fail
  /// return true to continue iteration.
  ///
  /// in [onRow] Like for transaction, no lengthy operation but access to database.
  Future<void> iterate(
    SdbClient client, {
    SdbTransactionMode? mode,
    SdbFindOptions<K>? options,
    required SdbCursorRowHandler<K, V> onRow,
  }) async {
    await impl.clientIterateImpl(
      client,
      mode: mode ?? SdbTransactionMode.readOnly,
      options: options ?? SdbFindOptions(),
      handler: onRow,
    );
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecords(
    SdbClient client, {

    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional sort order
    bool? descending,

    /// New API, supercedes the other parameters
    SdbFindOptions<K>? options,
  }) {
    options = sdbFindOptionsMerge(
      options,
      boundaries: boundaries,
      limit: limit,
      offset: offset,
      descending: descending,
      filter: filter,
    );
    return impl.findRecordsImpl(client, options: options);
  }

  /// Find records.
  Stream<SdbRecordSnapshot<K, V>> streamRecords(
    SdbClient client, {

    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,
    int? limit,

    /// Optional sort order
    bool? descending,

    /// New API, supercedes the other parameters
    SdbFindOptions<K>? options,
  }) {
    options = sdbFindOptionsMerge(
      options,
      boundaries: boundaries,
      limit: limit,
      offset: offset,
      descending: descending,
      filter: filter,
    );
    return impl.streamRecordsImpl(client, options: options);
  }

  /// Find first records
  Future<SdbRecordSnapshot<K, V>?> findRecord(
    SdbClient client, {

    SdbBoundaries<K>? boundaries,

    /// Optional filter, performed in memory
    SdbFilter? filter,
    int? offset,

    /// Optional sort order
    bool? descending,

    /// New API, supercedes the other parameters
    SdbFindOptions<K>? options,
  }) async {
    options = sdbFindOptionsMerge(
      options,
      boundaries: boundaries,
      offset: offset,
      descending: descending,
      filter: filter,
    );
    options = options.copyWith(limit: 1);
    var records = await findRecords(client, options: options);
    return records.firstOrNull;
  }

  /// Find records.
  Future<List<SdbRecordKey<K, V>>> findRecordKeys(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) => impl.findRecordKeysImpl(
    client,
    options: sdbFindOptionsMerge(
      boundaries: boundaries,
      options,
      limit: limit,
      offset: offset,
      descending: descending,
    ),
  );

  /// Count records.
  Future<int> count(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) => impl.countImpl(
    client,
    options: sdbFindOptionsMerge(options, boundaries: boundaries),
  );

  /// Delete records.
  Future<void> delete(
    SdbClient client, {
    SdbBoundaries<K>? boundaries,
    int? offset,
    int? limit,
    bool? descending,

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) => impl.deleteImpl(
    client,
    options: sdbFindOptionsMerge(
      options,
      boundaries: boundaries,
      limit: limit,
      offset: offset,
      descending: descending,
    ),
  );

  /// Listen for changes on a given store.
  ///
  /// Note that you can perform changes in the callback using the transaction
  /// provided. Also note that if you modify and already modified record,
  /// the callback will be called again.
  ///
  /// To use with caution as it has a cost.
  ///
  /// Like transaction, it can run multiple times, so limit your changes to the
  /// database.
  void addOnChangesListener(
    SdbDatabase database,
    SdbTransactionRecordChangeListener<K, V> onChanges, {
    List<String>? extraStoreNames,
  }) {
    database.dbInterface.changesListener.addStoreChangesListener(
      name,
      onChanges,
      extraStoreNames: extraStoreNames,
    );
  }

  /// Stop listening for changes.
  ///
  /// Make sure the same callback is used than the one used in addOnChangesListener.
  void removeOnChangesListener(
    SdbDatabase database,
    SdbTransactionRecordChangeListener<K, V> onChanges,
  ) {
    database.dbInterface.changesListener.removeStoreChangesListener(
      this,
      onChanges,
    );
  }
}

/// Store reference implementation.
class SdbStoreRefImpl<K extends SdbKey, V extends SdbValue>
    implements SdbStoreRef<K, V> {
  /// Store reference implementation.
  SdbStoreRefImpl(this.name) {
    sdbCheckKeyType<K>();
  }
  @override
  final String name;

  /// True if the key is an int.
  bool get isIntKey => K == int;

  @override
  String toString() => 'Store($name)';

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is SdbStoreRef) {
      return name == other.name;
    }
    return false;
  }

  /// Add a single record.
  Future<K> addImpl(SdbClient client, V value) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readWrite,
    (txn) => txnAddImpl(txn.txnInterface, value),
  );

  /// Add a single record.
  Future<K> txnAddImpl(SdbTransactionInterface txn, V value) {
    return txn.txnStoreInterface(this).addImpl(value);
  }

  /// Put a single record (inline keys)
  Future<K> putImpl(SdbClient client, V value) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readWrite,
    (txn) => txnPutImpl(txn.txnInterface, value),
  );

  /// Put a single record (inline keys)
  Future<K> txnPutImpl(SdbTransactionInterface txn, V value) {
    var txnStore = txn.txnStoreInterface(this);
    return txnStore.putImpl(null, value).then((_) {
      var keyPath = txnStore.keyPath;
      // Get the key from the value
      return mapValueAtKeyPath(
            value as Map,
            keyPath == null ? null : sdbKeyPathToIdbKeyPath(keyPath),
          )
          as K;
    });
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl(
    SdbClient client, {

    required SdbFindOptions<K> options,
  }) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,
    (txn) => txnFindRecordsImpl(txn.txnInterface, options: options),
  );

  /// Find records.
  Future<void> clientIterateImpl(
    SdbClient client, {
    required SdbTransactionMode mode,
    required SdbFindOptions<K> options,
    required SdbCursorRowHandler<K, V> handler,
  }) => clientAutoTxnImpl(
    client,
    mode,
    (txn) =>
        txnIterateImpl(txn.txnInterface, options: options, handler: handler),
  );

  /// Find records.
  Stream<SdbRecordSnapshot<K, V>> streamRecordsImpl(
    SdbClient client, {

    required SdbFindOptions<K> options,
  }) {
    if (client is SdbTransaction) {
      return txnStreamRecordsImpl(client.txnInterface, options: options);
    }
    return dbStreamRecordsImpl(client as SdbDatabase, options: options);
  }

  /// Find records.
  Stream<SdbRecordSnapshot<K, V>> dbStreamRecordsImpl(
    SdbDatabase db, {
    required SdbFindOptions<K> options,
  }) {
    var ctlr = SdbTxnStreamController<SdbRecordSnapshot<K, V>>();

    db.inStoreTransaction(this, SdbTransactionMode.readOnly, (txn) async {
      var stream = txnStreamRecordsImpl(txn.txnInterface, options: options);
      await ctlr.addStream(stream);
    });
    return ctlr.stream;
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> txnFindRecordsImpl(
    SdbTransactionInterface txn, {

    required SdbFindOptions<K> options,
  }) {
    return txn.txnStoreInterface(this).findRecordsImpl(options: options);
  }

  /// Find records.
  Future<void> txnIterateImpl(
    SdbTransactionInterface txn, {
    required SdbCursorRowHandler<K, V> handler,
    required SdbFindOptions<K> options,
  }) {
    return txn
        .txnStoreInterface(this)
        .iterateImpl(options: options, handler: handler);
  }

  /// Find records.
  Stream<SdbRecordSnapshot<K, V>> txnStreamRecordsImpl(
    SdbTransactionInterface txn, {
    required SdbFindOptions<K> options,
  }) {
    return txn.txnStoreInterface(this).streamRecordsImpl(options: options);
  }

  /// Find records keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl(
    SdbClient client, {
    required SdbFindOptions<K> options,
  }) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,
    (txn) => txnFindRecordKeysImpl(txn.txnInterface, options: options),
  );

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> txnFindRecordKeysImpl(
    SdbTransactionInterface txn, {
    required SdbFindOptions<K> options,
  }) {
    return txn.txnStoreInterface(this).findRecordKeysImpl(options: options);
  }

  /// Count records.
  Future<int> countImpl(SdbClient client, {SdbFindOptions<K>? options}) =>
      clientAutoTxnImpl(
        client,
        SdbTransactionMode.readOnly,
        (txn) => txnCountImpl(txn.txnInterface, options: options),
      );

  /// Count records.
  Future<int> txnCountImpl(
    SdbTransactionInterface txn, {
    SdbFindOptions<K>? options,
  }) {
    return txn
        .txnStoreInterface(this)
        .countImpl(options: options ?? SdbFindOptions<K>());
  }

  /// Delete records.
  Future<void> deleteImpl(
    SdbClient client, {
    required SdbFindOptions<K> options,
  }) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readWrite,
    (txn) => txnDeleteImpl(txn.txnInterface, options: options),
  );

  /// Find records.
  Future<void> dbDeleteImpl(
    SdbDatabase db, {
    required SdbFindOptions<K> options,
  }) {
    return db.inStoreTransaction(this, SdbTransactionMode.readWrite, (txn) {
      return txnDeleteImpl(txn.txnInterface, options: options);
    });
  }

  /// Find records.
  Future<void> txnDeleteImpl(
    SdbTransactionInterface txn, {

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) {
    return txn
        .txnStoreInterface(this)
        .deleteRecordsImpl(options: options ?? SdbFindOptions<K>());
  }

  /// Count records.
  Future<T> inTransactionImpl<T>(
    SdbDatabase db,
    SdbTransactionMode mode,
    Future<T> Function(SdbTransaction txn) fn,
  ) {
    return db.inStoreTransaction(this, mode, (txn) {
      return fn(txn);
    });
  }

  /// Auto transaction
  Future<T> dbAutoTxnImpl<T>(
    SdbDatabase db,
    SdbTransactionMode mode,
    Future<T> Function(SdbTransaction txn) fn,
  ) {
    return inTransactionImpl<T>(db, mode, fn);
  }

  /// Auto transaction
  Future<T> clientAutoTxnImpl<T>(
    SdbClient client,
    SdbTransactionMode mode,
    Future<T> Function(SdbTransaction txn) fn,
  ) async {
    if (client is SdbDatabase) {
      return await inTransactionImpl<T>(client, mode, fn);
    } else if (client is SdbTransaction) {
      return fn(client);
    } else {
      throw ArgumentError('Invalid client type: ${client.runtimeType}');
    }
  }

  /// Cast if needed
  @override
  SdbStoreRef<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>() {
    if (this is SdbStoreRef<RK, RV>) {
      return this as SdbStoreRef<RK, RV>;
    }
    return SdbStoreRef<RK, RV>(name);
  }
}

/// Controller for streaming transaction results.
///
/// [addStream] completes when the source is done or when the consumer cancels,
/// so that the transaction it runs in can complete: an implementation
/// serializing its transactions (sembast) would otherwise stay locked.
class SdbTxnStreamController<T> {
  void _onCancel() {
    _subscription?.cancel();
    _ctlr.close();
    _complete();
  }

  void _complete() {
    var completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Completer<void>? _completer;
  StreamSubscription? _subscription;
  late final _ctlr = StreamController<T>(sync: true, onCancel: _onCancel);

  /// Stream
  Stream<T> get stream => _ctlr.stream;

  /// Added stream.
  Future<void> addStream(Stream<T> source) async {
    var completer = _completer = Completer<void>();
    _subscription = source.listen(
      (event) {
        _ctlr.add(event);
      },
      //cancelOnError: true,
      onDone: () {
        _ctlr.close();
        _complete();
      },
      onError: (Object e, StackTrace s) {
        _ctlr.addError(e, s);
        if (!completer.isCompleted) {
          completer.completeError(e, s);
        }
      },
    );
    await completer.future;
  }

  /// Close the controller.
  void close() {
    _ctlr.close();
  }
}
