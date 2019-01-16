library tekartik_iodb.idb_meta;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:idb_shim/idb_client.dart';

abstract class TransactionWithMetaMixin {
  IdbTransactionMeta get meta;
}

class IdbTransactionMeta {
  String mode;
  List<String> storeNames;

  IdbTransactionMeta(this.storeNames, this.mode);

  void checkObjectStore(String storeName) {
    if (!storeNames.contains(storeName)) {
      throw DatabaseTransactionStoreNotFoundError(storeName);
    }
  }

  // ref counting
  // start on 0
  int refCount;

  @override
  String toString() => "${mode} ${storeNames}";
}

class IdbVersionChangeTransactionMeta extends IdbTransactionMeta {
  Map<String, List<IdbIndexMeta>> createdIndexes =
      {}; // index deleted during onUpgradeNeeded
  Map<String, List<IdbIndexMeta>> deletedIndexes =
      {}; // index deleted during onUpgradeNeeded
  Set<IdbObjectStoreMeta> createdStores =
      Set(); // store deleted during onUpgradeNeeded
  Set<IdbObjectStoreMeta> deletedStores =
      Set(); // store deleted during onUpgradeNeeded
  Set<IdbObjectStoreMeta> updatedStores =
      Set(); // store modified during onUpgradeNeeded

  IdbVersionChangeTransactionMeta() : super(null, idbModeReadWrite);

  // don't check for versionChangeTransaction
  @override
  void checkObjectStore(String storeName) {}
}

abstract class DatabaseWithMetaMixin {
  IdbDatabaseMeta get meta;

  //@implement
  String get name => meta.name;

  //@implement
  int get version => meta.version;

  //@override
  void deleteObjectStore(String name) {
    meta.deleteObjectStore(name);
  }

  //@override
  Iterable<String> get objectStoreNames => meta.objectStoreNames;

  @override
  String toString() {
    return meta.toString();
  }
}

class IdbDatabaseMeta {
  String name;
  int version;

  IdbDatabaseMeta([this.version]);

  IdbVersionChangeTransactionMeta _versionChangeTransaction;
  Map<String, IdbObjectStoreMeta> _stores = {};

  IdbVersionChangeTransactionMeta get versionChangeTransaction =>
      _versionChangeTransaction;

  Future onUpgradeNeeded(action()) async {
    _versionChangeTransaction = IdbVersionChangeTransactionMeta();

    var result = action();

    if (result is Future) {
      await result;
    }
    _versionChangeTransaction = null;
  }

  void createObjectStore(IdbObjectStoreMeta store) {
    if (versionChangeTransaction == null) {
      throw StateError(
          "cannot create objectStore outside of a versionChangedEvent");
    }
    versionChangeTransaction.createdStores.add(store);
    putObjectStore(store);
  }

  void deleteObjectStore(String storeName) {
    if (versionChangeTransaction == null) {
      throw StateError(
          "cannot delete objectStore outside of a versionChangedEvent");
    }
    // Get the store and add it to the change list so that
    // we store object store on quit
    IdbObjectStoreMeta storeMeta = _stores[storeName];
    if (storeMeta != null) {
      versionChangeTransaction.deletedStores.add(storeMeta);
      _stores.remove(storeName);
    } else {
      throw DatabaseStoreNotFoundError(
          DatabaseStoreNotFoundError.storeMessage(storeName));
    }
  }

  bool _containsStore(String storeName) {
    return _stores.keys.contains(storeName);
  }

  IdbTransactionMeta transaction(storeNameOrStoreNames, String mode) {
    // Check store(s) exist
    if (storeNameOrStoreNames is String) {
      if (!_containsStore(storeNameOrStoreNames)) {
        throw DatabaseStoreNotFoundError(
            DatabaseStoreNotFoundError.storeMessage(storeNameOrStoreNames));
      }
      return IdbTransactionMeta([storeNameOrStoreNames], mode);
    } else if (storeNameOrStoreNames is List) {
      if (storeNameOrStoreNames.isEmpty) {
        throw DatabaseError(
            "InvalidAccessError: The storeNames parameter is empty");
      }
      for (String storeName in storeNameOrStoreNames) {
        if (!_containsStore(storeName)) {
          throw DatabaseStoreNotFoundError(
              DatabaseStoreNotFoundError.storeMessage(storeNameOrStoreNames));
        }
      }
      return IdbTransactionMeta(storeNameOrStoreNames.cast<String>(), mode);
    } else if (storeNameOrStoreNames != null) {
      throw DatabaseError(
          "Invalid store name(s) parameter: ${storeNameOrStoreNames}");
    } else {
      // assume null - it will complain otherwise
      // this is use for transaction created on open
      return IdbTransactionMeta(null, mode);
    }
  }

  void putObjectStore(IdbObjectStoreMeta store) {
    _stores[store.name] = store;
  }

  Iterable<String> get objectStoreNames => _stores.keys;

  IdbObjectStoreMeta getObjectStore(String name) {
    return _stores[name];
  }

  Map<String, dynamic> toDebugMap() {
    var map = <String, dynamic>{"stores": _stores, "version": version};
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }

  @override
  int get hashCode => version;

  @override
  bool operator ==(o) {
    if (o is IdbDatabaseMeta) {
      return version == o.version;
    }
    return false;
  }
}

abstract class ObjectStoreWithMetaMixin {
  IdbObjectStoreMeta get meta;

  //@override
  dynamic get keyPath => meta.keyPath;

  //@override
  bool get autoIncrement => meta.autoIncrement;

  //@override
  String get name => meta.name;

  //@override
  List<String> get indexNames => meta.indexNames.toList();
}

// meta data is loaded only once
class IdbObjectStoreMeta {
  static const String nameKey = "name";
  static const String keyPathKey = "keyPath";
  static const String autoIncrementKey = "autoIncrement";
  static const String indeciesKey = "indecies";

  final String name;
  final String keyPath;
  final bool autoIncrement;

  Iterable<IdbIndexMeta> get indecies => _indecies.values;

  Map<String, IdbIndexMeta> _indecies = {};

  Iterable<String> get indexNames => _indecies.keys;

  IdbIndexMeta index(String name) {
    IdbIndexMeta indexMeta = _indecies[name];
    if (indexMeta == null) {
      throw ArgumentError("index $name not found");
    }
    return indexMeta;
  }

  void createIndex(IdbDatabaseMeta databaseMeta, IdbIndexMeta index) {
    if (databaseMeta.versionChangeTransaction == null) {
      throw StateError("cannot create index outside of a versionChangedEvent");
    }
    databaseMeta.versionChangeTransaction.updatedStores.add(this);
    List list = databaseMeta.versionChangeTransaction.createdIndexes[name];
    if (list == null) {
      databaseMeta.versionChangeTransaction.createdIndexes[name] = [index];
    } else {
      list.add(index);
    }
    putIndex(index);
  }

  void deleteIndex(IdbDatabaseMeta databaseMeta, String indexName) {
    if (databaseMeta.versionChangeTransaction == null) {
      throw StateError("cannot delete index outside of a versionChangedEvent");
    }
    IdbIndexMeta indexMeta = _indecies[indexName];
    if (indexMeta == null) {
      throw DatabaseIndexNotFoundError(indexName);
    }
    databaseMeta.versionChangeTransaction.updatedStores.add(this);
    List list = databaseMeta.versionChangeTransaction.deletedIndexes[name];
    if (list == null) {
      databaseMeta.versionChangeTransaction.deletedIndexes[name] = [indexMeta];
    } else {
      list.add(indexMeta);
    }
    removeIndex(indexMeta);
  }

  IdbObjectStoreMeta.fromObjectStore(ObjectStore objectStore)
      : this(objectStore.name, objectStore.keyPath as String,
            objectStore.autoIncrement);

  IdbObjectStoreMeta(this.name, this.keyPath, bool autoIncrement,
      [List<IdbIndexMeta> indecies])
      : autoIncrement = (autoIncrement == true) {
    if (indecies != null) {
      indecies.forEach((IdbIndexMeta indexMeta) {
        putIndex(indexMeta);
      });
    }
  }

  IdbObjectStoreMeta.fromMap(Map<String, dynamic> map) //
      : this(
            //
            map[nameKey] as String, //
            map[keyPathKey] as String, //
            map[autoIncrementKey] as bool,
            IdbIndexMeta.fromMapList(
                ((map[indeciesKey]) as List)?.cast<Map>()));

  IdbObjectStoreMeta clone() {
    return IdbObjectStoreMeta(name, keyPath, autoIncrement);
  }

  void putIndex(IdbIndexMeta index) {
    _indecies[index.name] = index;
  }

  void removeIndex(IdbIndexMeta index) {
    _indecies.remove(index.name);
  }

  Map<String, dynamic> toDebugMap() {
    return toMap();
  }

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{nameKey: name};
    if (keyPath != null) {
      map[keyPathKey] = keyPath;
    }
    if (autoIncrement) {
      map[autoIncrementKey] = autoIncrement;
    }
    if (indecies.isNotEmpty) {
      List<Map> indecies = [];
      this.indecies.forEach((IdbIndexMeta indexMeta) {
        indecies.add(indexMeta.toMap());
      });
      map[indeciesKey] = indecies;
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }

  @override
  int get hashCode => const MapEquality().hash(toMap());

  @override
  bool operator ==(o) {
    if (o is IdbObjectStoreMeta) {
      return const DeepCollectionEquality().equals(toMap(), o.toMap());
    }
    return false;
  }
}

class IdbCursorMeta {
  var key;

  bool get ascending => _ascending;
  final bool autoAdvance;

  KeyRange range;
  bool _ascending;

  String get direction => _ascending ? idbDirectionNext : idbDirectionPrev;

  IdbCursorMeta(this.key, this.range, String direction, bool autoAdvance)
      : autoAdvance = autoAdvance == true {
    if (direction == null) {
      direction = idbDirectionNext;
    }

    switch (direction) {
      case idbDirectionPrev:
        _ascending = false;
        break;
      case idbDirectionNext:
        _ascending = true;
        break;
      default:
        throw ArgumentError("direction '$direction' not supported");
    }
    if (key != null && range != null) {
      throw ArgumentError(
          "both key '${key}' and range '${range}' are specified");
    }
  }

  Map toDebugMap() {
    Map map = {"direction": direction};
    if (key != null) {
      map["key"] = key;
    }
    if (range != null) {
      map["range"] = range;
    }
    if (autoAdvance) {
      map["autoAdvance"] = autoAdvance;
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }
}

abstract class IndexWithMetaMixin {
  IdbIndexMeta get meta;

  //@override
  String get name => meta.name;

  //@override
  dynamic get keyPath => meta.keyPath;

  //@override
  bool get unique => meta.unique;

  //@override
  bool get multiEntry => meta.multiEntry;

  @override
  String toString() {
    return meta.toString();
  }
}

class IdbIndexMeta {
  final String name;
  final dynamic keyPath;
  final bool unique;
  final bool multiEntry;

  IdbIndexMeta(this.name, this.keyPath, bool unique, bool multiEntry)
      : multiEntry = (multiEntry == true),
        unique = (unique == true);

  static List<IdbIndexMeta> fromMapList(List<Map> list) {
    if (list == null) {
      return null;
    }
    var metas = <IdbIndexMeta>[];
    list.forEach((map) {
      metas.add(IdbIndexMeta.fromMap(map?.cast<String, dynamic>()));
    });
    return metas;
  }

  IdbIndexMeta.fromMap(Map<String, dynamic> map) //
      : this(
            map["name"] as String, //
            map["keyPath"] as String, //
            map["unique"] as bool, //
            map["multiEntry"] as bool);

  IdbIndexMeta.fromIndex(Index index)
      : this(index.name, index.keyPath as String, index.unique,
            index.multiEntry);

  Map toDebugMap() {
    return toMap();
  }

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{"name": name, "keyPath": keyPath};
    if (unique) {
      map["unique"] = unique;
    }
    if (multiEntry) {
      map["multiEntry"] = multiEntry;
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }

  @override
  int get hashCode => const MapEquality().hash(toMap());

  @override
  bool operator ==(o) {
    if (o is IdbIndexMeta) {
      return const MapEquality().equals(toMap(), o.toMap());
    }
    return false;
  }
}
