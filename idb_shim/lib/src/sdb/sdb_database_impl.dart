import 'dart:async';

import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/src/sdb/sdb_client.dart';
import 'package:idb_shim/src/sdb/sdb_database_impl.dart';
import 'package:meta/meta.dart';

import 'sdb.dart';
import 'sdb_changes_listener.dart';
import 'sdb_database.dart';
import 'sdb_factory_impl.dart';
import 'sdb_store_impl.dart';
import 'sdb_transaction_store_impl.dart';
import 'sdb_web_notification.dart';

/// SimpleDb database internal extension.
extension SdbDatabaseInternalExtension on SdbDatabase {
  /// Database implementation.
  SdbDatabaseImpl get impl => this as SdbDatabaseImpl;
}

/// Helper idb extension.
extension SdbDatabaseIdbExt on SdbDatabase {
  /// Database implementation.
  @visibleForTesting
  idb.Database get rawIdb => impl.idbDatabase;
}

/// SimpleDb implementation.
class SdbDatabaseImpl
    with SdbClientInterfaceDefaultMixin, SdbDatabaseDefaultMixin
    implements SdbDatabase, SdbClientInterface, SdbClientIdbInterface {
  /// Open options
  final SdbOpenDatabaseOptions? openOptions;

  /// Factory.
  @override
  final SdbFactoryImpl factory;

  /// Name.
  @override
  late final String name;

  /// Version
  @override
  int get version => idbDatabase.version;

  /// Set after open.
  late idb.Database idbDatabase;

  /// Codec used
  @override
  SdbCodec codec;

  /// Optional schema.
  SdbDatabaseSchema? get schema => openOptions?.schema;

  /// SimpleDb implementation.
  SdbDatabaseImpl(this.factory, this.name, {required this.openOptions})
    : codec = openOptions?.codec ?? SdbCodec.defaultCodec;

  /// SimpleDb implementation.
  SdbDatabaseImpl.idbDatabase(this.factory, this.idbDatabase, {SdbCodec? codec})
    : openOptions = null,
      codec = codec ?? SdbCodec.defaultCodec {
    name = idbDatabase.name;
  }

  @override
  Iterable<String> get storeNames => idbDatabase.objectStoreNames;

  /// Store change listeners
  final changesListener = SdbDatabaseChangesListener();

  /// Simulate a cross-tab notification for [storeNames]. For testing only.
  @visibleForTesting
  void simulateExternalStoreChanges(List<String> storeNames) {
    _externalChangesController?.add(storeNames);
  }

  StreamController<List<String>>? _externalChangesController;
  StreamSubscription<(String, List<String>)>? _externalChangesSubscription;

  /// Stream of store names changed by another tab. Lazily starts the
  /// BroadcastChannel listener when first subscribed to.
  Stream<List<String>> get externalStoreChanges {
    _externalChangesController ??= StreamController<List<String>>.broadcast(
      onListen: () {
        _externalChangesSubscription = sdbExternalStoreChangesStream
            .where((event) => event.$1 == name)
            .listen((event) => _externalChangesController?.add(event.$2));
      },
      onCancel: () {
        _externalChangesSubscription?.cancel();
        _externalChangesSubscription = null;
      },
    );
    return _externalChangesController!.stream;
  }

  /// Transaction.
  @override
  Future<T> inStoreTransaction<T, K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) async {
    var extraStoreNames = changesListener.storeGetExtraStoreNames(store.name);

    var txnStore = SdbTransactionStoreRefImpl<K, V>(store.impl);
    var txn = SdbSingleStoreTransactionImpl(
      impl,
      mode,
      txnStore,
      extraStoreNames: extraStoreNames,
    );
    return txn.run(callback);
  }

  @override
  Future<T> inStoresTransaction<T>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbMultiStoreTransaction txn) callback,
  ) {
    return inStoresTransactionImpl(stores, mode, callback);
  }

  /// Run a transaction.
  Future<T> inStoresTransactionImpl<T>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbMultiStoreTransaction txn) callback,
  ) {
    var extraStoreNames = changesListener.storesGetExtraStoreNames(
      stores.names,
    );

    var txn = SdbMultiStoreTransactionImpl(
      impl,
      mode,
      stores.names,
      extraStoreNames: extraStoreNames,
    );
    return txn.run(callback);
  }

  /// Run a transaction.
  /// Use either [storeNames] or [stores], mode default to read only
  @override
  Future<T> inTransaction<T>({
    List<String>? storeNames,
    List<SdbStoreRef>? stores,
    SdbTransactionMode? mode,
    required FutureOr<T> Function(SdbTransaction txn) run,
  }) {
    storeNames ??= stores?.map((e) => e.name).toList();
    if (storeNames?.isNotEmpty ?? false) {
      var extraStoreNames = changesListener.storesGetExtraStoreNames(
        storeNames!,
      );

      var txn = SdbMultiStoreTransactionImpl(
        impl,
        mode ?? SdbTransactionMode.readOnly,
        storeNames,
        extraStoreNames: extraStoreNames,
      );
      return txn.run(run);
    } else {
      throw ArgumentError(
        'Either storeNames ($storeNames) or stores ($stores) must be provided',
      );
    }
  }

  @override
  Future<T> clientHandleDbOrTxn<T>(
    Future<T> Function(SdbDatabase db) dbFn,
    Future<T> Function(SdbTransaction txn) txnFn,
  ) {
    return dbFn(this);
  }

  /// Close the database.
  @override
  Future<void> close() async {
    idbDatabase.close();
  }

  @override
  Future<K> sdbAddImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    V value,
  ) {
    return inStoreTransaction<K, K, V>(store, SdbTransactionMode.readWrite, (
      txn,
    ) {
      return txn.add(value);
    });
  }

  @override
  String toString() =>
      'SdbDatabase(name: ${logTruncateAny(name)}, version: ${logTruncateAny(version)} ${logTruncateAny(idbDatabase.objectStoreNames)})';

  @override
  SdbDatabase get db => this;
}
