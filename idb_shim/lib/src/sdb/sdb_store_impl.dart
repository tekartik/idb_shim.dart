import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/sdb/sdb_cursor.dart';
import 'package:idb_shim/src/sdb/sdb_key_utils.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

import 'sdb.dart';
import 'sdb_client.dart';
import 'sdb_database_impl.dart';
import 'sdb_transaction_impl.dart';

/// Store reference internal extension.
extension SdbStoreRefInternalExtension<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// Store reference implementation.
  SdbStoreRefImpl<K, V> get impl => this as SdbStoreRefImpl<K, V>;
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
  Future<void> handleRecords(
    SdbClient client, {
    SdbTransactionMode? mode,
    SdbFindOptions<K>? options,
    required SdbCursorRowHandler handler,
  }) async {
    await impl.handleRecordsImpl(
      client,
      mode: mode ?? SdbTransactionMode.readOnly,
      options: options ?? SdbFindOptions(),
      handler: handler,
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
    database.impl.changesListener.addStoreChangesListener(
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
    database.impl.changesListener.removeStoreChangesListener(this, onChanges);
  }
}

/// Store reference implementation.
class SdbStoreRefImpl<K extends SdbKey, V extends SdbValue>
    implements SdbStoreRef<K, V> {
  @override
  final String name;

  /// Store reference implementation.
  SdbStoreRefImpl(this.name) {
    sdbCheckKeyType<K>();
  }

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
    (txn) => txnAddImpl(txn.rawImpl, value),
  );

  /// Add a single record.
  Future<K> txnAddImpl(SdbTransactionImpl txn, V value) {
    return txn.storeImpl(this).add(value);
  }

  /// Put a single record (inline keys)
  Future<K> putImpl(SdbClient client, V value) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readWrite,
    (txn) => txnPutImpl(txn.rawImpl, value),
  );

  /// Put a single record (inline keys)
  Future<K> txnPutImpl(SdbTransactionImpl txn, V value) {
    return txn.storeImpl(this).put(null, value).then((_) {
      var keyPath = txn.storeImpl(this).idbObjectStore.keyPath;
      // Get the key from the value
      return mapValueAtKeyPath(value as Map, keyPath) as K;
    });
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl(
    SdbClient client, {

    required SdbFindOptions<K> options,
  }) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,
    (txn) => txnFindRecordsImpl(txn.rawImpl, options: options),
  );

  /// Find records.
  Future<void> handleRecordsImpl(
    SdbClient client, {
    required SdbTransactionMode mode,
    required SdbFindOptions<K> options,
    required SdbCursorRowHandler<K> handler,
  }) => clientAutoTxnImpl(
    client,
    mode,
    (txn) =>
        txnHandleRecordsImpl(txn.rawImpl, options: options, handler: handler),
  );

  /// Find records.
  Stream<SdbRecordSnapshot<K, V>> streamRecordsImpl(
    SdbClient client, {

    required SdbFindOptions<K> options,
  }) => client.handleDbOrTxn(
    (db) => dbStreamRecordsImpl(db, options: options),
    (txn) => txnStreamRecordsImpl(txn, options: options),
  );

  /// Find records.
  Stream<SdbRecordSnapshot<K, V>> dbStreamRecordsImpl(
    SdbDatabaseImpl db, {

    required SdbFindOptions<K> options,
  }) {
    var ctlr = SdbTxnStreamController<SdbRecordSnapshot<K, V>>();

    db.inStoreTransaction(this, SdbTransactionMode.readOnly, (txn) async {
      var stream = txnStreamRecordsImpl(txn.rawImpl, options: options);
      await ctlr.addStream(stream);
    });
    return ctlr.stream;
  }

  /// Find records.
  Future<List<SdbRecordSnapshot<K, V>>> txnFindRecordsImpl(
    SdbTransactionImpl txn, {

    required SdbFindOptions<K> options,
  }) {
    return txn.storeImpl(this).findRecords(options: options);
  }

  /// Find records.
  Future<void> txnHandleRecordsImpl(
    SdbTransactionImpl txn, {
    required SdbCursorRowHandler<K> handler,
    required SdbFindOptions<K> options,
  }) {
    return txn
        .storeImpl(this)
        .handleRecordsImpl(options: options, handler: handler);
  }

  /// Find records.
  Stream<SdbRecordSnapshot<K, V>> txnStreamRecordsImpl(
    SdbTransactionImpl txn, {
    required SdbFindOptions<K> options,
  }) {
    return txn.storeImpl(this).streamRecords(options: options);
  }

  /// Find records keys.
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl(
    SdbClient client, {
    required SdbFindOptions<K> options,
  }) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readOnly,
    (txn) => txnFindRecordKeysImpl(txn.rawImpl, options: options),
  );

  /// Find record keys.
  Future<List<SdbRecordKey<K, V>>> txnFindRecordKeysImpl(
    SdbTransactionImpl txn, {
    required SdbFindOptions<K> options,
  }) {
    return txn.storeImpl(this).findRecordKeys(options: options);
  }

  /// Count records.
  Future<int> countImpl(SdbClient client, {SdbFindOptions<K>? options}) =>
      clientAutoTxnImpl(
        client,
        SdbTransactionMode.readOnly,
        (txn) => txnCountImpl(txn.rawImpl, options: options),
      );

  /// Count records.
  Future<int> txnCountImpl(
    SdbTransactionImpl txn, {
    SdbFindOptions<K>? options,
  }) {
    return txn.storeImpl(this).count(options: options);
  }

  /// Delete records.
  Future<void> deleteImpl(
    SdbClient client, {
    required SdbFindOptions<K> options,
  }) => clientAutoTxnImpl(
    client,
    SdbTransactionMode.readWrite,
    (txn) => txnDeleteImpl(txn.rawImpl, options: options),
  );

  /// Find records.
  Future<void> dbDeleteImpl(
    SdbDatabase db, {
    required SdbFindOptions<K> options,
  }) {
    return db.inStoreTransaction(this, SdbTransactionMode.readWrite, (txn) {
      return txnDeleteImpl(txn.rawImpl, options: options);
    });
  }

  /// Find records.
  Future<void> txnDeleteImpl(
    SdbTransactionImpl txn, {

    /// New API, supersedes the other parameters
    SdbFindOptions<K>? options,
  }) {
    return txn.storeImpl(this).deleteRecords(options: options);
  }

  /// Count records.
  Future<T> inTransactionImpl<T>(
    SdbDatabase db,
    SdbTransactionMode mode,
    Future<T> Function(SdbTransaction txn) fn,
  ) {
    return db.inStoreTransaction(this, mode, (txn) {
      return fn(txn.rawImpl);
    });
  }

  /// Count records.
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
class SdbTxnStreamController<T> {
  void _onCancel() {
    _subscription?.cancel();
    _ctlr.close();
  }

  StreamSubscription? _subscription;
  late final _ctlr = StreamController<T>(sync: true, onCancel: _onCancel);

  /// Stream
  Stream<T> get stream => _ctlr.stream;

  /// Added stream.
  Future<void> addStream(Stream<T> source) async {
    var completer = Completer<void>();
    _subscription = source.listen(
      (event) {
        _ctlr.add(event);
      },
      //cancelOnError: true,
      onDone: () {
        _ctlr.close();
        if (!completer.isCompleted) {
          completer.complete();
        }
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
