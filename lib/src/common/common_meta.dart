library tekartik_iodb.idb_meta;

import 'package:idb_shim/idb_client.dart';
import 'package:collection/equality.dart';

class IdbTransactionMeta {
  String mode;
  List<String> storeNames;
  IdbTransactionMeta(this.storeNames, this.mode);

  // ref counting
  // start on 0
  int refCount;
}

class IdbDatabaseMeta {
  int version;

  IdbDatabaseMeta([this.version]);

  IdbTransactionMeta _versionChangeTransaction;
  Set<IdbObjectStoreMeta> versionChangeDeletedStores; // store deleted during onUpgradeNeeded
  Set<IdbObjectStoreMeta> versionChangeStores; // store modified during onUpgradeNeeded
  Map<String, IdbObjectStoreMeta> _stores = new Map();

  IdbTransactionMeta get versionChangeTransaction => _versionChangeTransaction;

  onUpgradeNeeded(action()) {
    versionChangeStores = new Set();
    versionChangeDeletedStores = new Set();
    _versionChangeTransaction =
        new IdbTransactionMeta(null, IDB_MODE_READ_WRITE);
    var result = action();
    _versionChangeTransaction = null;
    versionChangeStores = null;
    versionChangeDeletedStores = null;
    return result;
  }

  createObjectStore(IdbObjectStoreMeta store) {
    if (versionChangeTransaction == null) {
      throw new StateError(
          "cannot create objectStore outside of a versionChangedEvent");
    }
    versionChangeStores.add(store);
    addObjectStore(store);
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
      versionChangeDeletedStores.add(storeMeta);
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

  addObjectStore(IdbObjectStoreMeta store) {
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

// meta data is loaded only once
class IdbObjectStoreMeta {
  //final IdbDatabaseMeta databaseMeta;
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
    databaseMeta.versionChangeStores.add(this);
    addIndex(index);
  }

  IdbObjectStoreMeta.fromObjectStore(ObjectStore objectStore)
      : this(objectStore.name, objectStore.keyPath, objectStore.autoIncrement);

  IdbObjectStoreMeta(this.name, this.keyPath, bool autoIncrement,
      [List<IdbIndexMeta> indecies])
      : autoIncrement = (autoIncrement == true) {
    if (indecies != null) {
      indecies.forEach((IdbIndexMeta indexMeta) {
        addIndex(indexMeta);
      });
    }
  }

  IdbObjectStoreMeta.fromMap(Map<String, Object> map) //
      : this(
            //
            map["name"], //
            map["keyPath"], //
            map["autoIncrement"],
            IdbIndexMeta.fromMapList(map["indecies"]));

  IdbObjectStoreMeta clone() {
    return new IdbObjectStoreMeta(name, keyPath, autoIncrement);
  }

  addIndex(IdbIndexMeta index) {
    _indecies[index.name] = index;
  }

  Map toDebugMap() {
    return toMap();
  }

  Map<String, Object> toMap() {
    Map map = {"name": name};
    if (keyPath != null) {
      map["keyPath"] = keyPath;
    }
    if (autoIncrement) {
      map["autoIncrement"] = autoIncrement;
    }
    if (indecies.isNotEmpty) {
      List<Map> indecies = [];
      this.indecies.forEach((IdbIndexMeta indexMeta) {
        indecies.add(indexMeta.toMap());
      });
      map['indecies'] = indecies;
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

  String get direction => _ascending ? IDB_DIRECTION_NEXT : IDB_DIRECTION_PREV;

  IdbCursorMeta(this.key, this.range, String direction, bool autoAdvance)
      : autoAdvance = autoAdvance == true {
    if (direction == null) {
      direction = IDB_DIRECTION_NEXT;
    }

    switch (direction) {
      case IDB_DIRECTION_PREV:
        _ascending = false;
        break;
      case IDB_DIRECTION_NEXT:
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
