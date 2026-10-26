@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

final _valueStore = SdbStoreRef<String, SdbValue>('value');
final _modelStore = SdbStoreRef<String, SdbModel>('model');

Future<String> _blobText(Object? value) async =>
    (await ((value as SdbNativeValue).jsObject as web.Blob).text().toDart)
        .toDart;

void main() {
  group('sdb_native_value', () {
    var dbName = 'sdb_native_value.db';
    late SdbDatabase db;
    setUp(() async {
      await sdbFactoryWeb.deleteDatabase(dbName);
      db = await sdbFactoryWeb.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [_valueStore.schema(), _modelStore.schema()],
          ),
        ),
      );
    });
    tearDown(() async {
      await db.close();
    });

    test('value', () async {
      var record = _valueStore.record('blob');
      await record.put(db, SdbNativeValue(web.Blob(['hello'.toJS].toJS)));
      expect(await _blobText(await record.getValue(db)), 'hello');
    });

    test('model', () async {
      var root = await web.window.navigator.storage.getDirectory().toDart;
      var name = 'sdb_native_value.txt';
      var fileHandle = await root
          .getFileHandle(name, web.FileSystemGetFileOptions(create: true))
          .toDart;
      var record = _modelStore.record('model');
      var timestamp = SdbTimestamp(1, 2000);
      await record.put(db, {
        'name': 'test',
        'timestamp': timestamp,
        'blob': SdbNativeValue(web.Blob(['hello'.toJS].toJS)),
        'handles': [SdbNativeValue(fileHandle)],
      });
      var model = (await record.getValue(db))!;
      expect(model['name'], 'test');
      expect(model['timestamp'], timestamp);
      expect(await _blobText(model['blob']), 'hello');
      var readHandle =
          ((model['handles'] as List).first as SdbNativeValue).jsObject
              as web.FileSystemFileHandle;
      expect(readHandle.name, name);
      expect((await readHandle.isSameEntry(fileHandle).toDart).toDart, isTrue);
      await root.removeEntry(name).toDart;
    });
  }, skip: !idbFactoryNativeSupported);
}
