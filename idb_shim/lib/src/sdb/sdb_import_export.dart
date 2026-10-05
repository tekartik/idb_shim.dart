/// Export and import of an sdb database through the sdb api, for any
/// implementation, in the format of the sembast based idb implementation:
///
/// ```
/// {'sembast_export': 1, 'version': 1}
/// {'store': '_main'}
/// ['store_<name>', {'name': ..., 'keyPath': ..., 'autoIncrement': true, 'indecies': [...]}]
/// ['stores', [<names>]]
/// ['version', <database version>]
/// {'store': '<name>'}
/// [<key>, <raw value>]
/// ```
library;

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_cursor.dart';
import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/sdb/sdb_transaction_store.dart';
import 'package:idb_shim/src/sembast/sembast_value.dart';
import 'package:sembast/utils/type_adapter.dart';

/// The sembast export format encodes the values it cannot write as json
/// (Timestamp, Blob) and escapes the maps looking like them, through this
/// codec.
final _jsonEncodableCodec = sembastDefaultJsonEncodableCodec;

/// A raw (codec encoded) value as written in the export: the idb native types
/// (DateTime, Uint8List) become sembast ones (Timestamp, Blob), like in the
/// sembast based idb implementation, then the sembast json encoding is
/// applied (`@Timestamp`, `@Blob`, `@` escape).
Object _exportValue(Object rawValue) =>
    _jsonEncodableCodec.encode(toSembastValue(rawValue));

/// The raw (codec encoded) value of an exported value, see [_exportValue].
Object _importValue(Object exportedValue) =>
    fromSembastValue(_jsonEncodableCodec.decode(exportedValue));

const _exportSignatureKey = 'sembast_export';
const _exportSignatureVersion = 1;
const _exportVersionKey = 'version';
const _exportStoreKey = 'store';
const _exportStoresKey = 'stores';
const _exportKeysKey = 'keys';
const _exportValuesKey = 'values';
const _exportNameKey = 'name';

/// The sembast store holding the schema in the idb implementation.
const _mainStoreName = '_main';
const _mainVersionKey = 'version';
const _mainStoresKey = 'stores';
const _mainStorePrefix = 'store_';

const _metaNameKey = 'name';
const _metaKeyPathKey = 'keyPath';
const _metaAutoIncrementKey = 'autoIncrement';
const _metaIndeciesKey = 'indecies';
const _metaUniqueKey = 'unique';
const _metaMultiEntryKey = 'multiEntry';

/// Export a database in the sembast export lines format, through the sdb api.
Future<List<Object>> sdbExportDatabaseLinesGeneric(SdbDatabase db) async {
  var storeNames = db.storeNames.toList();
  var lines = <Object>[
    {_exportSignatureKey: _exportSignatureVersion, _exportVersionKey: 1},
    {_exportStoreKey: _mainStoreName},
  ];
  if (storeNames.isEmpty) {
    lines.add([_mainVersionKey, db.version]);
    return lines;
  }
  var storeRefs = storeNames
      .map((name) => SdbStoreRef<Object, Object>(name))
      .toList();
  var metas = <String, Map<String, Object?>>{};
  var records = <String, List<Object>>{};
  await db.inStoresTransaction(storeRefs, SdbTransactionMode.readOnly, (
    txn,
  ) async {
    for (var storeRef in storeRefs) {
      var txnStore = txn.store(storeRef);
      metas[storeRef.name] = _storeMetaMap(txnStore);
      var storeRecords = <Object>[];
      await storeRef.iterate(
        txn,
        onRow: (row) {
          storeRecords.add([row.key, _exportValue(row.rawValue)]);
          return true;
        },
      );
      records[storeRef.name] = storeRecords;
    }
  });
  // Like sembast, the records of the main store are in key order.
  var sortedNames = List.of(storeNames)..sort();
  for (var name in sortedNames) {
    lines.add(['$_mainStorePrefix$name', metas[name]]);
  }
  lines.add([_mainStoresKey, storeNames]);
  lines.add([_mainVersionKey, db.version]);
  // Stores in name order, the empty ones left out.
  for (var name in sortedNames) {
    var storeRecords = records[name]!;
    if (storeRecords.isEmpty) {
      continue;
    }
    lines.add({_exportStoreKey: name});
    lines.addAll(storeRecords);
  }
  return lines;
}

/// The store definition as the idb implementation stores it.
Map<String, Object?> _storeMetaMap(
  SdbTransactionStoreRef<Object, Object> store,
) {
  var map = <String, Object?>{_metaNameKey: store.name};
  var keyPath = store.keyPath;
  if (keyPath != null) {
    map[_metaKeyPathKey] = sdbKeyPathToIdbKeyPath(keyPath);
  }
  if (store.autoIncrement) {
    map[_metaAutoIncrementKey] = true;
  }
  var indexNames = store.indexNames.toList()..sort();
  if (indexNames.isNotEmpty) {
    map[_metaIndeciesKey] = indexNames.map((indexName) {
      var index = store.index(store.store.index<Object>(indexName));
      var indexMap = <String, Object?>{
        _metaNameKey: indexName,
        _metaKeyPathKey: sdbKeyPathToIdbKeyPath(index.keyPath),
      };
      if (index.unique) {
        indexMap[_metaUniqueKey] = true;
      }
      if (index.multiEntry) {
        indexMap[_metaMultiEntryKey] = true;
      }
      return indexMap;
    }).toList();
  }
  return map;
}

/// Import a database export (lines or map), through the sdb api: the
/// destination is deleted, created with the exported schema and version, and
/// the raw values written as they were.
Future<SdbDatabase> sdbImportDatabaseGeneric(
  Object data,
  SdbFactory dstFactory,
  String dstDbName, {
  SdbCodec? codec,
}) async {
  var export = _SdbExportData.parse(data);
  var storeNames = export.storeNames;
  var storeRefs = <String, SdbStoreRef<Object, Object>>{
    for (var name in storeNames) name: SdbStoreRef<Object, Object>(name),
  };
  var schema = SdbDatabaseSchema(
    stores: storeNames.map((name) {
      var storeRef = storeRefs[name]!;
      var meta = export.metas[name] ?? {_metaNameKey: name};
      var keyPath = meta[_metaKeyPathKey];
      var indecies = (meta[_metaIndeciesKey] as List?) ?? const [];
      return SdbStoreSchema(
        storeRef,
        keyPath: keyPath == null ? null : sdbKeyPathFromAny(keyPath),
        autoIncrement: meta[_metaAutoIncrementKey] == true,
        indexes: indecies.map((item) {
          var indexMeta = item as Map;
          var indexName = indexMeta[_metaNameKey] as String;
          return SdbIndexSchema(
            storeRef.index<Object>(indexName),
            sdbKeyPathFromAny(indexMeta[_metaKeyPathKey] as Object),
            unique: indexMeta[_metaUniqueKey] == true,
          );
        }).toList(),
      );
    }).toList(),
  );
  await dstFactory.deleteDatabase(dstDbName);
  var db = await dstFactory.openDatabase(
    dstDbName,
    options: SdbOpenDatabaseOptions(
      version: export.version,
      schema: schema,
      codec: codec,
    ),
  );
  var storesWithRecords = export.records.keys
      .where((name) => export.records[name]!.isNotEmpty)
      .toList();
  if (storesWithRecords.isNotEmpty) {
    await db.inStoresTransaction(
      storesWithRecords.map((name) => storeRefs[name]!).toList(),
      SdbTransactionMode.readWrite,
      (txn) async {
        for (var name in storesWithRecords) {
          var txnStore =
              txn.store(storeRefs[name]!)
                  as SdbTransactionStoreRefInterface<Object, Object>;
          for (var record in export.records[name]!) {
            await txnStore.putRawImpl(record.$1, _importValue(record.$2));
          }
        }
      },
    );
  }
  return db;
}

/// A parsed export.
class _SdbExportData {
  _SdbExportData._();

  /// Parse the lines or the map export.
  factory _SdbExportData.parse(Object data) {
    var export = _SdbExportData._();
    if (data is Map) {
      export._parseMap(data);
    } else if (data is List) {
      export._parseLines(data);
    } else {
      throw ArgumentError.value(data, 'data', 'List of lines or Map expected');
    }
    export._fixStoreNames();
    return export;
  }

  /// Database version, null when not exported.
  int? version;

  /// The store names in creation order.
  var storeNames = <String>[];

  /// Store definitions by name.
  final metas = <String, Map<String, Object?>>{};

  /// Records by store name.
  final records = <String, List<(Object, Object)>>{};

  void _checkHeader(Map header) {
    if (header[_exportSignatureKey] != _exportSignatureVersion) {
      throw FormatException('Invalid export header $header');
    }
  }

  void _parseLines(List lines) {
    if (lines.isEmpty) {
      throw const FormatException('Empty export');
    }
    _checkHeader(lines.first as Map);
    String? storeName;
    for (var line in lines.skip(1)) {
      if (line is Map) {
        storeName = line[_exportStoreKey] as String;
      } else if (line is List && line.length == 2) {
        if (storeName == null) {
          throw FormatException('Record $line before any store');
        }
        _addRecord(storeName, line[0] as Object, line[1] as Object);
      } else {
        throw FormatException('Invalid export line $line');
      }
    }
  }

  void _parseMap(Map map) {
    _checkHeader(map);
    var stores = (map[_exportStoresKey] as List?) ?? const [];
    for (var store in stores) {
      var storeMap = store as Map;
      var storeName = storeMap[_exportNameKey] as String;
      var keys = storeMap[_exportKeysKey] as List;
      var values = storeMap[_exportValuesKey] as List;
      for (var i = 0; i < keys.length; i++) {
        _addRecord(storeName, keys[i] as Object, values[i] as Object);
      }
    }
  }

  void _addRecord(String storeName, Object key, Object value) {
    if (storeName == _mainStoreName) {
      if (key == _mainVersionKey) {
        version = value as int;
      } else if (key == _mainStoresKey) {
        storeNames = (value as List).cast<String>();
      } else if (key is String && key.startsWith(_mainStorePrefix)) {
        var meta = (value as Map).cast<String, Object?>();
        var name =
            meta[_metaNameKey] as String? ??
            key.substring(_mainStorePrefix.length);
        metas[name] = meta;
      }
      return;
    }
    (records[storeName] ??= []).add((key, value));
  }

  /// Every store with a definition or records is in [storeNames].
  void _fixStoreNames() {
    var names = List.of(storeNames);
    for (var name in [...metas.keys, ...records.keys]) {
      if (!names.contains(name)) {
        names.add(name);
      }
    }
    storeNames = names;
  }
}
