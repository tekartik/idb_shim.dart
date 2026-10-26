@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/src/native_web/js_utils.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

bool _same(Object jsObject, JSAny other) =>
    (jsObject as JSAny).strictEquals(other).toDart;

void main() {
  group('native_value_utils', () {
    test('isJSPlainObject', () {
      expect(JSObject().isJSPlainObject, isTrue);
      expect(<String, Object?>{'a': 1}.jsifyValue().isJSPlainObject, isTrue);
      expect(web.Blob().isJSPlainObject, isFalse);
    });
    test('jsify/dartify', () {
      var blob = web.Blob();
      var jsValue = IdbNativeValue(blob).jsifyValue();
      expect(jsValue.strictEquals(blob).toDart, isTrue);
      var value = jsValue.dartifyValue() as IdbNativeValue;
      expect(_same(value.jsObject, blob), isTrue);

      var map =
          <String, Object?>{
                'name': 'test',
                'blob': IdbNativeValue(blob),
                'list': [IdbNativeValue(blob), 1],
              }.jsifyValue().dartifyValue()
              as Map;
      expect(map['name'], 'test');
      expect(_same((map['blob'] as IdbNativeValue).jsObject, blob), isTrue);
      var list = map['list'] as List;
      expect(_same((list[0] as IdbNativeValue).jsObject, blob), isTrue);
      expect(list[1], 1);
    });
  });

  group('native_value', () {
    var dbName = 'idb_native_value.db';
    var storeName = 'test';
    late Database db;
    setUp(() async {
      await idbFactoryNative.deleteDatabase(dbName);
      db = await idbFactoryNative.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (event) {
          event.database.createObjectStore(storeName);
        },
      );
    });
    tearDown(() {
      db.close();
    });

    Future<void> put(Object value, Object key) async {
      var txn = db.transaction(storeName, idbModeReadWrite);
      await txn.objectStore(storeName).put(value, key);
      await txn.completed;
    }

    Future<Object?> get(Object key) async {
      var txn = db.transaction(storeName, idbModeReadOnly);
      var value = await txn.objectStore(storeName).getObject(key);
      await txn.completed;
      return value;
    }

    test('blob', () async {
      var blob = web.Blob(['hello'.toJS].toJS);
      await put(IdbNativeValue(blob), 'blob');
      var value = await get('blob') as IdbNativeValue;
      var readBlob = value.jsObject as web.Blob;
      expect(readBlob.instanceOfString('Blob'), isTrue);
      expect((await readBlob.text().toDart).toDart, 'hello');
    });

    test('nested', () async {
      var blob = web.Blob(['hello'.toJS].toJS);
      await put({
        'name': 'test',
        'blob': IdbNativeValue(blob),
        'list': [IdbNativeValue(blob), 1],
      }, 'map');
      var map = await get('map') as Map;
      expect(map['name'], 'test');
      var readBlob = (map['blob'] as IdbNativeValue).jsObject as web.Blob;
      expect((await readBlob.text().toDart).toDart, 'hello');
      var list = map['list'] as List;
      expect(list[0], isA<IdbNativeValue>());
      expect(list[1], 1);
    });

    test('getAll and cursor', () async {
      await put(IdbNativeValue(web.Blob(['1'.toJS].toJS)), 1);
      await put(IdbNativeValue(web.Blob(['2'.toJS].toJS)), 2);
      var txn = db.transaction(storeName, idbModeReadOnly);
      var store = txn.objectStore(storeName);
      var all = await store.getAll();
      var cursorValues = await store
          .openCursor(autoAdvance: true)
          .map((cursor) => cursor.value)
          .toList();
      await txn.completed;
      for (var values in [all, cursorValues]) {
        expect(values, hasLength(2));
        var texts = [
          for (var value in values)
            (await ((value as IdbNativeValue).jsObject as web.Blob)
                    .text()
                    .toDart)
                .toDart,
        ];
        expect(texts, ['1', '2']);
      }
    });

    test('opfs file handle', () async {
      var root = await web.window.navigator.storage.getDirectory().toDart;
      var name = 'idb_native_value.txt';
      var fileHandle = await root
          .getFileHandle(name, web.FileSystemGetFileOptions(create: true))
          .toDart;
      var writable = await fileHandle.createWritable().toDart;
      await writable.write('hello'.toJS).toDart;
      await writable.close().toDart;

      await put(IdbNativeValue(fileHandle), 'file');
      await put(IdbNativeValue(root), 'dir');

      var readHandle =
          (await get('file') as IdbNativeValue).jsObject
              as web.FileSystemFileHandle;
      expect(readHandle.instanceOfString('FileSystemFileHandle'), isTrue);
      expect(readHandle.name, name);
      expect((await readHandle.isSameEntry(fileHandle).toDart).toDart, isTrue);
      var file = await readHandle.getFile().toDart;
      expect((await file.text().toDart).toDart, 'hello');

      var readDirHandle =
          (await get('dir') as IdbNativeValue).jsObject
              as web.FileSystemDirectoryHandle;
      expect(
        readDirHandle.instanceOfString('FileSystemDirectoryHandle'),
        isTrue,
      );
      expect((await readDirHandle.isSameEntry(root).toDart).toDart, isTrue);

      await root.removeEntry(name).toDart;
    });
  }, skip: !idbFactoryNativeSupported);
}
