// ignore_for_file: public_member_api_docs

library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/utils/core_imports.dart';

abstract mixin class TransactionWithMetaMixin {
  IdbTransactionMeta? get meta;
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
  int refCount = 0;

  @override
  String toString() => '$mode $storeNames';
}

class IdbVersionChangeTransactionMeta extends IdbTransactionMeta {
  // index deleted during onUpgradeNeeded
  final createdIndexes = <String, List<IdbIndexMeta>>{};

  // index deleted during onUpgradeNeeded
  final deletedIndexes = <String, List<IdbIndexMeta>>{};

  // stores created during onUpgradeNeeded
  // ignore: prefer_collection_literals
  final createdStores = Set<IdbObjectStoreMeta>();

  // stores deleted during onUpgradeNeeded
  // ignore: prefer_collection_literals
  final deletedStores = Set<IdbObjectStoreMeta>();

  // stores modified during onUpgradeNeeded
  // ignore: prefer_collection_literals
  final updatedStores = Set<IdbObjectStoreMeta>();

  IdbVersionChangeTransactionMeta() : super([], idbModeReadWrite);

  // don't check for versionChangeTransaction
  @override
  void checkObjectStore(String storeName) {}
}

abstract mixin class DatabaseWithMetaMixin {
  IdbDatabaseMeta get meta;

  //@implement
  String get name => meta.name;

  //@implement
  int get version => meta.version ?? 0;

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
  late String name;
  int? version;

  IdbDatabaseMeta([this.version]);

  IdbVersionChangeTransactionMeta? _versionChangeTransaction;
  final _stores = <String, IdbObjectStoreMeta>{};

  IdbVersionChangeTransactionMeta? get versionChangeTransaction =>
      _versionChangeTransaction;

  Future onUpgradeNeeded(dynamic Function() action) async {
    _versionChangeTransaction = IdbVersionChangeTransactionMeta();
    try {
      var result = action();

      if (result is Future) {
        await result;
      }
    } catch (e) {
      // devPrint('onUpgradeNeeded error $e');
      rethrow;
    } finally {
      _versionChangeTransaction = null;
    }
  }

  void createObjectStore(IdbObjectStoreMeta store) {
    if (versionChangeTransaction == null) {
      throw StateError(
        'cannot create objectStore outside of a versionChangedEvent',
      );
    }
    versionChangeTransaction!.createdStores.add(store);
    putObjectStore(store);
  }

  void deleteObjectStore(String storeName) {
    if (versionChangeTransaction == null) {
      throw StateError(
        'cannot delete objectStore outside of a versionChangedEvent',
      );
    }
    // Get the store and add it to the change list so that
    // we store object store on quit
    final storeMeta = _stores[storeName];
    if (storeMeta != null) {
      versionChangeTransaction!.deletedStores.add(storeMeta);
      _stores.remove(storeName);
    } else {
      throw DatabaseStoreNotFoundError(
        DatabaseStoreNotFoundError.storeMessage(storeName),
      );
    }
  }

  bool _containsStore(String storeName) {
    return _stores.keys.contains(storeName);
  }

  /// Allow null for initial transaction
  IdbTransactionMeta transaction(Object? storeNameOrStoreNames, String mode) {
    // Check store(s) exist
    if (storeNameOrStoreNames is String) {
      if (!_containsStore(storeNameOrStoreNames)) {
        throw DatabaseStoreNotFoundError(
          DatabaseStoreNotFoundError.storeMessage(storeNameOrStoreNames),
        );
      }
      return IdbTransactionMeta([storeNameOrStoreNames], mode);
    } else if (storeNameOrStoreNames is List) {
      if (storeNameOrStoreNames.isEmpty) {
        throw DatabaseError(
          'InvalidAccessError: The storeNames parameter is empty',
        );
      }
      final list = storeNameOrStoreNames.cast<String>();

      for (final storeName in list) {
        if (!_containsStore(storeName)) {
          throw DatabaseStoreNotFoundError(
            DatabaseStoreNotFoundError.storeMessage(storeNameOrStoreNames),
          );
        }
      }
      return IdbTransactionMeta(storeNameOrStoreNames.cast<String>(), mode);
    } else {
      // assume null - it will complain otherwise
      // this is use for transaction created on open
      return IdbTransactionMeta([], mode);
    }
  }

  void putObjectStore(IdbObjectStoreMeta store) {
    _stores[store.name] = store;
  }

  Iterable<String> get objectStoreNames => _stores.keys;

  IdbObjectStoreMeta? getObjectStore(String name) {
    return _stores[name];
  }

  Map<String, Object?> toDebugMap() {
    var map = <String, Object?>{'stores': _stores, 'version': version};
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }

  @override
  int get hashCode => version!;

  @override
  bool operator ==(Object other) {
    if (other is IdbDatabaseMeta) {
      return version == other.version;
    }
    return false;
  }
}

abstract mixin class ObjectStoreWithMetaMixin {
  IdbObjectStoreMeta? get meta;

  //@override
  Object? get keyPath => meta!.keyPath;

  //@override
  bool get autoIncrement => meta!.autoIncrement;

  //@override
  String /*!*/ get name => meta!.name;

  //@override
  List<String> get indexNames => meta!.indexNames.toList();
}

/// IndexedDB object store meta data is loaded only once
class IdbObjectStoreMeta {
  /// Name key.
  static const String nameKey = 'name';
  static const String keyPathKey = 'keyPath';
  static const String autoIncrementKey = 'autoIncrement';
  static const String indeciesKey = 'indecies';

  final String name;
  final Object? keyPath;
  final bool autoIncrement;

  Iterable<IdbIndexMeta> get indecies => _indecies.values;

  final _indecies = <String?, IdbIndexMeta>{};

  Iterable<String> get indexNames => _indecies.keys.cast<String>();

  IdbIndexMeta index(String name) {
    final indexMeta = _indecies[name];
    if (indexMeta == null) {
      throw ArgumentError('index $name not found');
    }
    return indexMeta;
  }

  void createIndex(IdbDatabaseMeta databaseMeta, IdbIndexMeta index) {
    if (databaseMeta.versionChangeTransaction == null) {
      throw StateError('cannot create index outside of a versionChangedEvent');
    }
    databaseMeta.versionChangeTransaction!.updatedStores.add(this);
    List? list = databaseMeta.versionChangeTransaction!.createdIndexes[name];
    if (list == null) {
      databaseMeta.versionChangeTransaction!.createdIndexes[name] = [index];
    } else {
      list.add(index);
    }
    putIndex(index);
  }

  void deleteIndex(IdbDatabaseMeta databaseMeta, String indexName) {
    if (databaseMeta.versionChangeTransaction == null) {
      throw StateError('cannot delete index outside of a versionChangedEvent');
    }
    final indexMeta = _indecies[indexName];
    if (indexMeta == null) {
      throw DatabaseIndexNotFoundError(indexName);
    }
    databaseMeta.versionChangeTransaction!.updatedStores.add(this);
    List? list = databaseMeta.versionChangeTransaction!.deletedIndexes[name];
    if (list == null) {
      databaseMeta.versionChangeTransaction!.deletedIndexes[name] = [indexMeta];
    } else {
      list.add(indexMeta);
    }
    removeIndex(indexMeta);
  }

  IdbObjectStoreMeta.fromObjectStore(ObjectStore objectStore)
    : this(objectStore.name, objectStore.keyPath, objectStore.autoIncrement);

  IdbObjectStoreMeta(
    this.name,
    this.keyPath,
    bool? autoIncrement, [
    List<IdbIndexMeta>? indecies,
  ]) : autoIncrement = (autoIncrement == true) {
    if (indecies != null) {
      for (var indexMeta in indecies) {
        putIndex(indexMeta);
      }
    }
  }

  static Object? _keyPathAsStringOrList(Object? keyPath) {
    if (keyPath is Iterable) {
      return keyPath.cast<String>().toList();
    } else {
      return keyPath?.toString();
    }
  }

  IdbObjectStoreMeta.fromMap(Map<String, Object?> map) //
    : this(
        //
        map[nameKey] as String, //
        _keyPathAsStringOrList(map[keyPathKey]),
        map[autoIncrementKey] as bool?,
        IdbIndexMeta.fromMapList(((map[indeciesKey]) as List?)?.cast<Map>()),
      );

  IdbObjectStoreMeta clone() {
    return IdbObjectStoreMeta(name, keyPath, autoIncrement);
  }

  void putIndex(IdbIndexMeta index) {
    _indecies[index.name] = index;
  }

  void removeIndex(IdbIndexMeta index) {
    _indecies.remove(index.name);
  }

  Map<String, Object?> toDebugMap() {
    return toMap();
  }

  Map<String, Object?> toMap() {
    var map = <String, Object?>{nameKey: name};
    if (keyPath != null) {
      map[keyPathKey] = keyPath;
    }
    if (autoIncrement) {
      map[autoIncrementKey] = autoIncrement;
    }
    if (indecies.isNotEmpty) {
      final indecies = <Map>[];
      // Sort to always have the same export format
      var indexMetas = List<IdbIndexMeta>.from(this.indecies)
        ..sort((meta1, meta2) => meta1.name!.compareTo(meta2.name!));
      for (var indexMeta in indexMetas) {
        indecies.add(indexMeta.toMap());
      }
      map[indeciesKey] = indecies;
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is IdbObjectStoreMeta) {
      return const DeepCollectionEquality().equals(toMap(), other.toMap());
    }
    return false;
  }
}

class IdbCursorMeta {
  dynamic key;

  bool get ascending => _ascending;
  final bool autoAdvance;

  KeyRange? range;
  late bool _ascending;

  String get direction => _ascending ? idbDirectionNext : idbDirectionPrev;

  IdbCursorMeta(this.key, this.range, String? direction, bool? autoAdvance)
    : autoAdvance = autoAdvance ?? false {
    direction ??= idbDirectionNext;

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
      throw ArgumentError("both key '$key' and range '$range' are specified");
    }
    if (key is KeyRange) {
      throw ArgumentError(
        'Invalid keyRange $key as key argument, use the range argument',
      );
    }
  }

  Map<String, Object?> toDebugMap() {
    final map = <String, Object?>{'direction': direction};
    if (key != null) {
      map['key'] = key;
    }
    if (range != null) {
      map['range'] = range;
    }
    if (autoAdvance) {
      map['autoAdvance'] = autoAdvance;
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }
}

abstract mixin class IndexWithMetaMixin {
  IdbIndexMeta get meta;

  //@override
  String get name => meta.name!;

  //@override
  Object get keyPath => meta.keyPath;

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
  final String? name;
  final Object keyPath;
  final bool unique;
  final bool multiEntry;

  IdbIndexMeta(this.name, this.keyPath, bool? unique, bool? multiEntry)
    : multiEntry = (multiEntry == true),
      unique = (unique == true);

  static List<IdbIndexMeta>? fromMapList(List<Map>? list) {
    if (list == null) {
      return null;
    }
    var metas = <IdbIndexMeta>[];
    for (var map in list) {
      metas.add(IdbIndexMeta.fromMap(map.cast<String, Object?>()));
    }
    return metas;
  }

  factory IdbIndexMeta.fromMap(Map<String, Object?> map) {
    var meta = IdbIndexMeta(
      map['name'] as String, //
      _keyPathAsStringOrList(map['keyPath'] as Object),
      map['unique'] as bool?, //
      map['multiEntry'] as bool?,
    );
    return meta;
  }

  IdbIndexMeta.fromIndex(Index index)
    : this(index.name, index.keyPath, index.unique, index.multiEntry);

  Map toDebugMap() {
    return toMap();
  }

  Map<String, Object?> toMap() {
    dynamic keyPath;
    if (this.keyPath is Iterable) {
      keyPath = (this.keyPath as Iterable).cast<String>().toList();
    } else {
      keyPath = this.keyPath.toString();
    }
    var map = <String, Object?>{'name': name, 'keyPath': keyPath};
    if (unique) {
      map['unique'] = unique;
    }
    if (multiEntry) {
      map['multiEntry'] = multiEntry;
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }

  @override
  int get hashCode => name.hashCode; //const MapEquality().hash(toMap());

  @override
  bool operator ==(Object other) {
    if (other is IdbIndexMeta) {
      return const DeepCollectionEquality().equals(toMap(), other.toMap());
    }
    return false;
  }
}

Object _keyPathAsStringOrList(Object keyPath) =>
    _keyPathAsStringOrListOrNull(keyPath)!;

Object? _keyPathAsStringOrListOrNull(Object? keyPath) {
  if (keyPath is Iterable) {
    return keyPath.cast<String>().toList();
  } else {
    return keyPath?.toString();
  }
}
