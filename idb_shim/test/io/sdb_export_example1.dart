/// The exhaustive example database of `test/data` (2 stores, 5 records,
/// every type), shared by the export tests.
library;

import 'dart:typed_data';

import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';

final _noteStore = SdbStoreRef<int, SdbModel>('note');
final _noteTitleIndex = _noteStore.index<String>('title');
final _settingStore = SdbStoreRef<String, Object>('setting');

/// The note holding every type.
Map<String, Object?> _allTypesNote() => {
  'title': 'world',
  'date': DateTime.utc(2026, 11, 2, 12, 30),
  'bytes': Uint8List.fromList([1, 2, 3]),
  'int': -3,
  'bigInt': 9007199254740991,
  'double': 4.5,
  'true': true,
  'false': false,
  'null': null,
  'text': 'été ✓',
  'list': [
    1,
    [2, 'three'],
    <String, Object?>{},
    <Object?>[],
  ],
  'nested': {'done': true, 'empty': <String, Object?>{}},
};

/// The database of the example: a store with a key path, auto increment and
/// an index, a store without, every type and maps looking like an encoded
/// type.
Future<SdbDatabase> sdbCreateExample1(SdbFactory factory, String name) async {
  await factory.deleteDatabase(name);
  var db = await factory.openDatabase(
    name,
    options: SdbOpenDatabaseOptions(
      version: 2,
      schema: SdbDatabaseSchema(
        stores: [
          _noteStore.schema(
            keyPath: SdbKeyPath.single('id'),
            autoIncrement: true,
            indexes: [
              _noteTitleIndex.schema(keyPath: SdbKeyPath.single('title')),
            ],
          ),
          _settingStore.schema(),
        ],
      ),
    ),
  );
  await _noteStore.add(db, {
    'title': 'hello',
    'tags': ['a', 'b'],
  });
  await _noteStore.add(db, _allTypesNote());
  await _settingStore.record('theme').put(db, 'dark');
  await _settingStore.record('escaped_at').put(db, {
    '@Timestamp': 'not a timestamp',
  });
  await _settingStore.record('escaped_dollar').put(db, {
    r'$blob': 'not a blob',
  });
  return db;
}

/// The content of the example database.
///
/// [checkAutoIncrement] adds (then deletes) a record: the key generator does
/// not go back, call it once per imported database.
Future<void> sdbCheckExample1(
  SdbDatabase db, {
  bool checkAutoIncrement = true,
}) async {
  expect(db.version, 2);
  expect(db.storeNames.toList()..sort(), ['note', 'setting']);
  expect(await _noteStore.record(1).getValue(db), {
    'id': 1,
    'title': 'hello',
    'tags': ['a', 'b'],
  });
  var world = (await _noteTitleIndex.record('world').getValue(db))!;
  expect(world, {..._allTypesNote(), 'id': 2});
  expect(world['date'], isA<DateTime>());
  expect(world['bytes'], isA<Uint8List>());
  expect(await _noteStore.count(db), 2);
  expect(await _settingStore.count(db), 3);
  expect((await _settingStore.record('theme').get(db))!.value, 'dark');
  expect((await _settingStore.record('escaped_at').get(db))!.value, {
    '@Timestamp': 'not a timestamp',
  });
  expect((await _settingStore.record('escaped_dollar').get(db))!.value, {
    r'$blob': 'not a blob',
  });
  if (checkAutoIncrement) {
    // The auto increment goes on after the imported keys.
    expect(await _noteStore.add(db, {'title': 'next'}), 3);
    await _noteStore.record(3).delete(db);
  }
}
