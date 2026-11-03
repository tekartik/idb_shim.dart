/// The custom types example of `test/data/sdb_types_*.jsonl`: the sdb
/// custom types (SdbTimestamp, SdbBlob, stored as `{"$Timestamp": ...}` and
/// `{"$Blob": ...}` by the default codec) next to the native ones (DateTime,
/// Uint8List) and maps looking like them.
library;

import 'dart:typed_data';

import 'package:dev_test/test.dart';
import 'package:idb_shim/sdb.dart';

final _typeStore = SdbStoreRef<String, Object>('type');

/// The map holding every type, nested.
Map<String, Object?> _allTypesMap() => {
  'timestamp': SdbTimestamp(1793622600, 0),
  'blob': SdbBlob(Uint8List.fromList([255])),
  'dateTime': DateTime.utc(2026, 11, 2, 12, 30),
  'bytes': Uint8List.fromList([4, 5]),
  'list': [SdbTimestamp(0, 0), SdbBlob(Uint8List(0)), 1],
};

/// The custom types example database, 1 store, 5 records.
Future<SdbDatabase> sdbExportTypesCreateExample1(
  SdbFactory factory,
  String name,
) async {
  await factory.deleteDatabase(name);
  var db = await factory.openDatabase(
    name,
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(stores: [_typeStore.schema()]),
    ),
  );
  await _typeStore
      .record('timestamp')
      .put(db, SdbTimestamp(1793622600, 123456000));
  await _typeStore
      .record('blob')
      .put(db, SdbBlob(Uint8List.fromList([1, 2, 3])));
  await _typeStore.record('map').put(db, _allTypesMap());
  // Maps looking like a stored custom type.
  await _typeStore.record('escaped_dollar').put(db, {
    r'$Timestamp': 'not a timestamp',
  });
  await _typeStore.record('escaped_at').put(db, {'@Blob': 'not a blob'});
  return db;
}

/// The content of the custom types example database.
Future<void> sdbExportTypesCheckExample1(SdbDatabase db) async {
  expect(db.version, 1);
  expect(await _typeStore.count(db), 5);
  var timestamp = await _typeStore.record('timestamp').getValue(db);
  expect(timestamp, isA<SdbTimestamp>());
  expect(timestamp, SdbTimestamp(1793622600, 123456000));
  var blob = await _typeStore.record('blob').getValue(db);
  expect(blob, isA<SdbBlob>());
  expect(blob, SdbBlob(Uint8List.fromList([1, 2, 3])));
  var map = (await _typeStore.record('map').getValue(db))! as Map;
  expect(map, _allTypesMap());
  expect(map['timestamp'], isA<SdbTimestamp>());
  expect(map['blob'], isA<SdbBlob>());
  expect(map['dateTime'], isA<DateTime>());
  expect(map['bytes'], isA<Uint8List>());
  expect((map['list'] as List)[0], isA<SdbTimestamp>());
  expect((map['list'] as List)[1], isA<SdbBlob>());
  expect(await _typeStore.record('escaped_dollar').getValue(db), {
    r'$Timestamp': 'not a timestamp',
  });
  expect(await _typeStore.record('escaped_at').getValue(db), {
    '@Blob': 'not a blob',
  });
}
