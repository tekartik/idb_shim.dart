import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_shim/src/common/common_database.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/sembast/sembast_factory.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/sembast/sembast_transaction.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sdb;

class _SdbVersionChangeEvent extends IdbVersionChangeEventBase {
  @override
  final int oldVersion;
  @override
  final int newVersion;
  Request request;

  @override
  Object get target => request;

  @override
  Database get database => transaction.database;

  /// added for convenience
  @override
  TransactionSembast get transaction =>
      request.transaction as TransactionSembast;

  _SdbVersionChangeEvent(
      DatabaseSembast database, int oldVersion, this.newVersion) //
      : oldVersion = oldVersion ?? 0 {
    // handle = too to catch programatical errors
    if (this.oldVersion >= newVersion) {
      throw StateError('cannot downgrade from $oldVersion to $newVersion');
    }
    request = OpenDBRequest(database, database.versionChangeTransaction);
  }

  @override
  String toString() {
    return '$oldVersion => $newVersion';
  }
}

///
/// meta format
/// {'key':'version','value':1}
/// {'key':'stores','value':['test_store']}
/// {'key':'store_test_store','value':{'name':'test_store','keyPath':'my_key','autoIncrement':true}}

class DatabaseSembast extends IdbDatabaseBase with DatabaseWithMetaMixin {
  TransactionSembast versionChangeTransaction;
  @override
  final IdbDatabaseMeta meta = IdbDatabaseMeta();
  sdb.Database db;

  @override
  IdbFactorySembast get factory => super.factory as IdbFactorySembast;

  sdb.DatabaseFactory get sdbFactory => factory.sdbFactory;

  DatabaseSembast._(IdbFactory factory) : super(factory);

  final mainStore = sdb.StoreRef<String, dynamic>.main();

  static Future<DatabaseSembast> fromDatabase(
      IdbFactory factory, sdb.Database db) async {
    final idbDb = DatabaseSembast._(factory);
    idbDb.db = db;
    var version = await idbDb._readMeta();
    // Copy name from path
    idbDb.meta.name = db.path;
    // devPrint('fromDatabase version $version meta ${idbDb.meta.version}');
    idbDb.meta.version = version ?? 1;
    return idbDb;
  }

  DatabaseSembast(IdbFactory factory, String name) : super(factory) {
    meta.name = name;
  }

  Future<List<IdbObjectStoreMeta>> _loadStoresMeta(List<String> storeNames) {
    final keys = <String>[];
    storeNames.forEach((String storeName) {
      keys.add('store_$storeName');
    });

    return mainStore.records(keys).getSnapshots(db).then((records) {
      final list = <IdbObjectStoreMeta>[];
      records.forEach((record) {
        var map = (record.value as Map)?.cast<String, dynamic>();
        final store = IdbObjectStoreMeta.fromMap(map);
        list.add(store);
      });
      return list;
    });
  }

  // return the previous version
  Future<int> _readMeta() async {
    return db.transaction((txn) async {
      // devPrint(await mainStore.find(txn));

      // read version
      meta.version = await mainStore.record('version').get(txn) as int;
      // devPrint('read meta version ${meta.version} ${db.path}');
      // read store meta
      var storeList = await mainStore.record('stores').get(txn);
      if (storeList != null) {
        // for now load all at once
        final storeNames = (storeList as List)?.cast<String>();
        await _loadStoresMeta(storeNames)
            .then((List<IdbObjectStoreMeta> storeMetas) {
          storeMetas.forEach((IdbObjectStoreMeta store) {
            meta.putObjectStore(store);
          });
        });
      }
      return meta.version;
    });
  }

  Future<sdb.Database> open(
      int newVersion, OnUpgradeNeededFunction onUpgradeNeeded) async {
    int previousVersion;

    // devPrint('open ${onUpgradeNeeded} ${onUpgradeNeeded != null ? 'NOT NULL': 'NULL'}');
    if (sembastDebug) {
      print(
          'open2 $onUpgradeNeeded ${onUpgradeNeeded != null ? 'NOT NULL' : 'NULL'}');
    }
    // Open the sembast database
    db = await sdbFactory.openDatabase(factory.getDbPath(name), version: 1,
        onVersionChanged: (db, oldVersion, newVersion) {
      if (sembastDebug) {
        print('changing ${db.path} $oldVersion -> $newVersion');
      }
    });
    previousVersion = await _readMeta();
    // devPrint('Opening $name previous $previousVersion new $newVersion version $version');
    // If not specify and previous version is null, force new version to 1
    if (previousVersion == null) {
      newVersion ??= 1;
    }
    if (newVersion != null && newVersion != previousVersion) {
      Set<IdbObjectStoreMeta> changedStores;
      Set<IdbObjectStoreMeta> deletedStores;

      await meta.onUpgradeNeeded(() async {
        versionChangeTransaction =
            TransactionSembast(this, meta.versionChangeTransaction);
        // could be null when opening an empty database
        if (onUpgradeNeeded != null) {
          onUpgradeNeeded(
              _SdbVersionChangeEvent(this, previousVersion, newVersion));
        }
        changedStores = Set.from(meta.versionChangeTransaction.createdStores);
        changedStores.addAll(meta.versionChangeTransaction.updatedStores);
        deletedStores = meta.versionChangeTransaction.deletedStores;
      });

      await db.transaction((txn) async {
        await mainStore.record('version').put(txn, newVersion);

        // First delete everything from deleted stores
        for (final storeMeta in deletedStores) {
          await sdb.StoreRef(storeMeta.name).drop(txn);
        }

        // Handle deleted object store
        if (changedStores.isNotEmpty || deletedStores.isNotEmpty) {
          await mainStore.record('stores').put(
              txn,
              List.from(objectStoreNames)
                ..sort()); // Sort the names to always have the same export
        }

        for (final storeMeta in changedStores) {
          await mainStore
              .record('store_${storeMeta.name}')
              .put(txn, storeMeta.toMap());
        }
      }).then((_) {
        // considered as opened
        meta.version = newVersion;
      });
    } else {
      // Keep existing meta
      meta.version = previousVersion ?? 1;
    }
    return db;
  }

  @override
  void close() {
    db.close();
  }

  @override
  ObjectStore createObjectStore(String name,
      {String keyPath, bool autoIncrement}) {
    final storeMeta = IdbObjectStoreMeta(name, keyPath, autoIncrement);
    meta.createObjectStore(storeMeta);
    return ObjectStoreSembast(versionChangeTransaction, storeMeta);
  }

  @override
  void deleteObjectStore(String name) {
    meta.deleteObjectStore(name);
  }

  @override
  Iterable<String> get objectStoreNames {
    return meta.objectStoreNames;
  }

  @override
  Stream<VersionChangeEvent> get onVersionChange {
    throw 'not implemented yet';
  }

  @override
  Transaction transaction(storeNameOrStoreNames, String mode) {
    //if (_debugTransaction) {
    //  print('transaction($storeName_OR_storeNames)');
    // }
    final txnMeta = meta.transaction(storeNameOrStoreNames, mode);
    return TransactionSembast(this, txnMeta);
  }

  @override
  Transaction transactionList(List<String> storeNames, String mode) {
    final txnMeta = meta.transaction(storeNames, mode);
    return TransactionSembast(this, txnMeta);
  }

  @override
  int get version => meta.version;

  Map toDebugMap() {
    Map map;
    if (meta != null) {
      map = meta.toDebugMap();
    } else {
      map = {};
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }
}
