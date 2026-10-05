import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:meta/meta.dart';

import 'sdb_changes_listener.dart';
import 'sdb_client.dart';
import 'sdb_web_notification.dart';

/// SimpleDb database.
///
/// A database is a collection of stores.
/// The database has a version.
/// The database has a name.
/// The database has a factory.
///
/// A database can be opened using [SdbFactory.openDatabase].
///
/// A database can be closed using [SdbDatabase.close].
abstract class SdbDatabase implements SdbClient {
  /// Run a transaction on a single store.
  ///
  /// [store] is the store to run the transaction on.
  /// [mode] is the transaction mode, either [SdbTransactionMode.readOnly] or
  /// [SdbTransactionMode.readWrite].
  /// [callback] is the function to run in the transaction.
  Future<T> inStoreTransaction<T, K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  );

  /// Run a transaction on multiple stores.
  ///
  /// [stores] is the list of stores to run the transaction on.
  /// [mode] is the transaction mode, either [SdbTransactionMode.readOnly] or
  /// [SdbTransactionMode.readWrite].
  /// [callback] is the function to run in the transaction.
  Future<T> inStoresTransaction<T>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbMultiStoreTransaction txn) callback,
  );

  /// Run a transaction.
  /// Use either [storeNames] or [stores], mode default to read only
  Future<T> inTransaction<T>({
    List<String>? storeNames,
    List<SdbStoreRef>? stores,
    SdbTransactionMode? mode,
    required FutureOr<T> Function(SdbTransaction txn) run,
  });

  /// Get the version of the database.
  int get version;

  /// Get the name of the database.
  String get name;

  /// Factory
  SdbFactory get factory;

  /// Close the database.
  Future<void> close();

  /// True once closed, by [close] or on its own when another connection
  /// opened a newer version or deleted the database
  /// ([SdbOpenDatabaseOptions.versionChangeAction]).
  bool get isClosed;
}

/// SimpleDb methods.
extension SdbDatabaseExtension on SdbDatabase {
  /// Get the openDatabaseOptions used to open the database
  /// Could be null, if an existing database is opened without open options
  /// without schema information
  SdbOpenDatabaseOptions? get openDatabaseOptions {
    return (this as SdbDatabaseInterface).openOptions;
  }
}

/// Internal interface implemented by every database, idb based or not.
abstract class SdbDatabaseInterface implements SdbDatabase, SdbClientInterface {
  /// The options used to open the database, null if opened without.
  SdbOpenDatabaseOptions? get openOptions;

  /// The change listeners of the stores, see
  /// [SdbStoreRefDbExtension.addOnChangesListener].
  SdbDatabaseChangesListener get changesListener;

  /// The names of the stores changed by another connection (another browser
  /// tab), what the onSnapshot streams redo their query on.
  Stream<List<String>> get externalStoreChanges;
}

/// Internal extension.
extension SdbDatabaseExtensionPrv on SdbDatabase {
  /// Internal interface.
  SdbDatabaseInterface get dbInterface => this as SdbDatabaseInterface;
}

/// Default mixin
mixin SdbDatabaseDefaultMixin implements SdbDatabaseInterface {
  @override
  final changesListener = SdbDatabaseChangesListener();

  StreamController<List<String>>? _externalChangesController;
  StreamSubscription<(String, List<String>)>? _externalChangesSubscription;

  /// Simulate a cross-tab notification for [storeNames]. For testing only.
  @visibleForTesting
  void simulateExternalStoreChanges(List<String> storeNames) {
    _externalChangesController?.add(storeNames);
  }

  /// Lazily starts the BroadcastChannel listener when first subscribed to.
  @override
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

  @override
  Future<void> close() {
    throw UnimplementedError('close');
  }

  @override
  Future<T> inStoreTransaction<T, K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) {
    throw UnimplementedError('inStoreTransaction');
  }

  @override
  Future<T> inStoresTransaction<T>(
    List<SdbStoreRef<SdbKey, SdbValue>> stores,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbMultiStoreTransaction txn) callback,
  ) {
    throw UnimplementedError('inStoresTransaction');
  }

  @override
  Future<T> clientHandleDbOrTxn<T>(
    Future<T> Function(SdbDatabase db) dbFn,
    Future<T> Function(SdbTransaction txn) txnFn,
  ) {
    throw UnimplementedError('clientHandleDbOrTxn');
  }

  @override
  int get version => throw UnimplementedError('version');

  @override
  bool get isClosed => throw UnimplementedError('isClosed');
}
