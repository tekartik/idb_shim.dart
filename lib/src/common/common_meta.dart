library tekartik_iodb.idb_meta;

import 'package:idb_shim/idb_client.dart';
import 'package:collection/equality.dart';
import 'dart:async';

abstract class TransactionWithMetaMixin {
  IdbTransactionMeta get meta;
}

class IdbTransactionMeta {
  String mode;
  List<String> storeNames;
  IdbTransactionMeta(this.storeNames, this.mode);

  void checkObjectStore(String storeName) {
    if (!storeNames.contains(storeName)) {
      throw new DatabaseTransactionStoreNotFoundError(storeName);
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
      {}; // store deleted during onUpgradeNeeded
  Set<IdbObjectStoreMeta> createdStores =
      new Set(); // store deleted during onUpgradeNeeded
  Set<IdbObjectStoreMeta> deletedStores =
      new Set(); // store deleted during onUpgradeNeeded
  Set<IdbObjectStoreMeta> updatedStores =
      new Set(); // store modified during onUpgradeNeeded

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
  Map<String, IdbObjectStoreMeta> _stores = new Map();

  IdbVersionChangeTransactionMeta get versionChangeTransaction =>
      _versionChangeTransaction;

  onUpgradeNeeded(action()) async {
    _versionChangeTransaction = new IdbVersionChangeTransactionMeta();

    var result = action();

    if (result is Future) {
      await result;
    }
    _versionChangeTransaction = null;
  }

  createObjectStore(IdbObjectStoreMeta store) {
    if (versionChangeTransaction == null) {
      throw new StateError(
          "cannot create objectStore outside of a versionChangedEvent");
    }
    versionChangeTransaction.createdStores.add(store);
    putObjectStore(store);
  }

  deleteObjectStore(String storeName) {
    if (versionChangeTransaction == null) {
      throw new StateError(
          "cannot delete objectStore outside of a versionChangedEvent");
    }
    // Get the store and add it to the change list so that
    // we store object store on quit
    IdbObjectStoreMeta storeMeta = _stores[storeName];
    if (storeMeta != null) {
      versionChangeTransaction.deletedStores.add(storeMeta);
      _stores.remove(storeName);
    }
  }

  bool _containsStore(String storeName) {
    return _stores.keys.contains(storeName);
  }

  IdbTransactionMeta transaction(storeName_OR_storeNames, String mode) {
    // Check store(s) exist
    if (storeName_OR_storeNames is String) {
      if (!_containsStore(storeName_OR_storeNames)) {
        throw new DatabaseStoreNotFoundError();
      }
      return new IdbTransactionMeta([storeName_OR_storeNames], mode);
    } else if (storeName_OR_storeNames is List) {
      for (String storeName in storeName_OR_storeNames) {
        if (!_containsStore(storeName)) {
          throw new DatabaseStoreNotFoundError();
        }
      }
      return new IdbTransactionMeta(storeName_OR_storeNames, mode);
    } else {
      // assume null - it will complain otherwise
      return new IdbTransactionMeta(storeName_OR_storeNames, mode);
    }
  }

  putObjectStore(IdbObjectStoreMeta store) {
    _stores[store.name] = store;
  }

  Iterable<String> get objectStoreNames => _stores.keys;

  IdbObjectStoreMeta getObjectStore(String name) {
    return _stores[name];
  }

  Map<String, Object> toDebugMap() {
    Map map = {"stores": _stores, "version": version};
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }

  @override
  int get hashCode => version;

  @override
  operator ==(o) {
    if (o is IdbDatabaseMeta) {
      return version == o.version;
    }
    return false;
  }
}

abstract class ObjectStoreWithMetaMixin {
  IdbObjectStoreMeta get meta;

  //@override
  get keyPath => meta.keyPath;

  //@override
  get autoIncrement => meta.autoIncrement;

  //@override
  get name => meta.name;

  //@override
  List<String> get indexNames => meta.indexNames.toList();
}

// meta data is loaded only once
class IdbObjectStoreMeta {
  static const String NAME_KEY = "name";
  static const String KEY_PATH_KEY = "keyPath";
  static const String AUTO_INCREMENT_KEY = "autoIncrement";
  static const String INDECIES_KEY = "indecies";

  //final IdbDatabaseMeta databaseMeta;
  // might be set later...
  // TODO check if can be final
  final String name;
  final String keyPath;
  final bool autoIncrement;

  Iterable<IdbIndexMeta> get indecies => _indecies.values;

  Map<String, IdbIndexMeta> _indecies = new Map();

  Iterable<String> get indexNames => _indecies.keys;

  IdbIndexMeta index(String name) {
    IdbIndexMeta indexMeta = _indecies[name];
    if (indexMeta == null) {
      throw new ArgumentError("index $name not found");
    }
    return indexMeta;
  }

  createIndex(IdbDatabaseMeta databaseMeta, IdbIndexMeta index) {
    if (databaseMeta.versionChangeTransaction == null) {
      throw new StateError(
          "cannot create index outside of a versionChangedEvent");
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

  IdbObjectStoreMeta.fromObjectStore(ObjectStore objectStore)
      : this(objectStore.name, objectStore.keyPath, objectStore.autoIncrement);

  IdbObjectStoreMeta(this.name, this.keyPath, bool autoIncrement,
      [List<IdbIndexMeta> indecies])
      : autoIncrement = (autoIncrement == true) {
    if (indecies != null) {
      indecies.forEach((IdbIndexMeta indexMeta) {
        putIndex(indexMeta);
      });
    }
  }

  IdbObjectStoreMeta.fromMap(Map<String, Object> map) //
      : this(
            //
            map[NAME_KEY], //
            map[KEY_PATH_KEY], //
            map[AUTO_INCREMENT_KEY],
            IdbIndexMeta.fromMapList(map[INDECIES_KEY]));

  IdbObjectStoreMeta clone() {
    return new IdbObjectStoreMeta(name, keyPath, autoIncrement);
  }

  putIndex(IdbIndexMeta index) {
    _indecies[index.name] = index;
  }

  Map toDebugMap() {
    return toMap();
  }

  Map<String, Object> toMap() {
    Map map = {NAME_KEY: name};
    if (keyPath != null) {
      map[KEY_PATH_KEY] = keyPath;
    }
    if (autoIncrement) {
      map[AUTO_INCREMENT_KEY] = autoIncrement;
    }
    if (indecies.isNotEmpty) {
      List<Map> indecies = [];
      this.indecies.forEach((IdbIndexMeta indexMeta) {
        indecies.add(indexMeta.toMap());
      });
      map[INDECIES_KEY] = indecies;
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }

  @override
  int get hashCode => toMap().hashCode;

  @override
  operator ==(o) {
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
        throw new ArgumentError("direction '$direction' not supported");
    }
    if (key != null && range != null) {
      throw new ArgumentError(
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
  String get keyPath => meta.keyPath;

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
  final String keyPath;
  final bool unique;
  final bool multiEntry;
  IdbIndexMeta(this.name, this.keyPath, bool unique, bool multiEntry)
      : multiEntry = (multiEntry == true),
        unique = (unique == true);

  static List<IdbIndexMeta> fromMapList(List<Map> list) {
    if (list == null) {
      return null;
    }
    var metas = [];
    list.forEach((map) {
      metas.add(new IdbIndexMeta.fromMap(map));
    });
    return metas;
  }

  IdbIndexMeta.fromMap(Map<String, Object> map) //
      : this(
            map["name"], //
            map["keyPath"], //
            map["unique"], //
            map["multiEntry"]);

  IdbIndexMeta.fromIndex(Index index)
      : this(index.name, index.keyPath, index.unique, index.multiEntry);

  Map toDebugMap() {
    return toMap();
  }

  Map<String, Object> toMap() {
    Map map = {"name": name, "keyPath": keyPath};
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
  int get hashCode => toMap().hashCode;

  @override
  operator ==(o) {
    if (o is IdbIndexMeta) {
      return const MapEquality().equals(toMap(), o.toMap());
    }
    return false;
  }
}
