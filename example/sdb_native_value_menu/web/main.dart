import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/utils/sdb_import_export.dart';
import 'package:tekartik_test_menu_browser/test_menu_web.dart';
import 'package:web/web.dart' as web;

const _dbName = 'sdb_native_value_menu.db';

/// Records holding a native value (alone or inside a model).
final _store = SdbStoreRef<String, SdbValue>('values');

/// OPFS directory of the demo entries.
const _opfsDirName = 'sdb_native_value_menu';
const _opfsFileName = 'hello.txt';

/// `window.showOpenFilePicker()`, Chromium-only, not in `package:web`.
@JS('window.showOpenFilePicker')
external JSPromise<JSArray<web.FileSystemFileHandle>> _showOpenFilePicker();

/// `window.showDirectoryPicker()`, Chromium-only, not in `package:web`.
@JS('window.showDirectoryPicker')
external JSPromise<web.FileSystemDirectoryHandle> _showDirectoryPicker();

/// Permission API, Chromium-only, not in `package:web`.
extension on web.FileSystemHandle {
  @JS('queryPermission')
  external JSPromise<JSString> _queryPermission(JSObject descriptor);

  @JS('requestPermission')
  external JSPromise<JSString> _requestPermission(JSObject descriptor);
}

JSObject _readPermission() => JSObject()..['mode'] = 'read'.toJS;

Future<String> _queryPermission(web.FileSystemHandle handle) async {
  if (!handle.has('queryPermission')) {
    return 'granted (no permission API)';
  }
  return (await handle._queryPermission(_readPermission()).toDart).toDart;
}

Future<String> _requestPermission(web.FileSystemHandle handle) async {
  if (!handle.has('requestPermission')) {
    return 'granted (no permission API)';
  }
  return (await handle._requestPermission(_readPermission()).toDart).toDart;
}

Future<SdbDatabase> _openDb([SdbFactory? factory]) =>
    (factory ?? sdbFactoryWeb).openDatabase(
      _dbName,
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [_store.schema()]),
      ),
    );

Future<T> _withDb<T>(Future<T> Function(SdbDatabase db) action) async {
  var db = await _openDb();
  try {
    return await action(db);
  } finally {
    await db.close();
  }
}

Future<void> _put(String key, SdbValue value) async {
  await _withDb((db) => _store.record(key).put(db, value));
  write('put $key: ${await _describe(value)}');
}

Future<SdbValue?> _get(String key) =>
    _withDb((db) => _store.record(key).getValue(db));

/// The handles found in the records (alone or inside a model).
Future<List<(String, web.FileSystemHandle)>> _handles() async {
  var records = await _withDb((db) => _store.findRecords(db));
  var handles = <(String, web.FileSystemHandle)>[];
  void add(String key, Object? value) {
    if (value is SdbNativeValue) {
      var jsObject = value.jsObject as JSObject;
      if (jsObject.instanceOfString('FileSystemHandle')) {
        handles.add((key, jsObject as web.FileSystemHandle));
      }
    } else if (value is Map) {
      value.forEach((field, item) => add('$key.$field', item));
    } else if (value is List) {
      for (var (index, item) in value.indexed) {
        add('$key[$index]', item);
      }
    }
  }

  for (var record in records) {
    add(record.key, record.value);
  }
  return handles;
}

/// The OPFS root directory has no name.
String _handleName(web.FileSystemHandle handle) =>
    handle.name.isEmpty ? '(OPFS root)' : handle.name;

String _short(String text) =>
    text.length > 60 ? '${text.substring(0, 60)}...' : text;

Future<String> _blobText(web.Blob blob) async =>
    _short((await blob.text().toDart).toDart);

String _constructorName(JSObject jsObject) => jsObject
    .getProperty<JSObject>('constructor'.toJS)
    .getProperty<JSString>('name'.toJS)
    .toDart;

/// Readable description of a stored value, reading the native values.
Future<String> _describe(Object? value) async {
  if (value is SdbNativeValue) {
    var jsObject = value.jsObject as JSObject;
    try {
      if (jsObject.instanceOfString('FileSystemFileHandle')) {
        var handle = jsObject as web.FileSystemFileHandle;
        var file = await handle.getFile().toDart;
        return 'FileSystemFileHandle ${handle.name} '
            '(${file.size} bytes): ${await _blobText(file)}';
      } else if (jsObject.instanceOfString('FileSystemDirectoryHandle')) {
        var handle = jsObject as web.FileSystemDirectoryHandle;
        return 'FileSystemDirectoryHandle ${_handleName(handle)}';
      } else if (jsObject.instanceOfString('File')) {
        var file = jsObject as web.File;
        return 'File ${file.name} (${file.size} bytes, ${file.type}): '
            '${await _blobText(file)}';
      } else if (jsObject.instanceOfString('Blob')) {
        var blob = jsObject as web.Blob;
        return 'Blob (${blob.size} bytes, ${blob.type}): '
            '${await _blobText(blob)}';
      } else if (jsObject.instanceOfString('CryptoKey')) {
        var key = jsObject as web.CryptoKey;
        var algorithm = key.algorithm.getProperty<JSString>('name'.toJS);
        return 'CryptoKey ${algorithm.toDart} '
            '(extractable: ${key.extractable}, '
            'usages: ${key.usages.dartify()})';
      }
      return 'SdbNativeValue(${_constructorName(jsObject)})';
    } catch (e) {
      // File moved or deleted (NotFoundError), permission lost after a
      // reload (NotAllowedError)...
      return '${_constructorName(jsObject)}: $e';
    }
  } else if (value is Map) {
    var fields = [
      for (var entry in value.entries)
        '${entry.key}: ${await _describe(entry.value)}',
    ];
    return '{${fields.join(', ')}}';
  } else if (value is List) {
    return '[${[for (var item in value) await _describe(item)].join(', ')}]';
  } else if (value is SdbBlob) {
    return 'SdbBlob(${value.bytes.length} bytes)';
  }
  return '$value';
}

/// A file of the OPFS (available in every browser).
Future<web.FileSystemFileHandle> _opfsFileHandle() async {
  var root = await web.window.navigator.storage.getDirectory().toDart;
  var dir = await root
      .getDirectoryHandle(
        _opfsDirName,
        web.FileSystemGetDirectoryOptions(create: true),
      )
      .toDart;
  var handle = await dir
      .getFileHandle(_opfsFileName, web.FileSystemGetFileOptions(create: true))
      .toDart;
  var writable = await handle.createWritable().toDart;
  await writable.write('Hello OPFS at ${DateTime.now()}'.toJS).toDart;
  await writable.close().toDart;
  return handle;
}

/// AES-GCM parameters.
JSObject _aesGcm(Uint8List iv) => JSObject()
  ..['name'] = 'AES-GCM'.toJS
  ..['iv'] = iv.toJS;

Future<void> main() async {
  await initTestMenuBrowser();

  menu('sdb native values (sdbFactoryWeb)', () {
    item('put Blob', () async {
      await _put(
        'blob',
        SdbNativeValue(
          web.Blob(
            ['Hello Blob'.toJS].toJS,
            web.BlobPropertyBag(type: 'text/plain'),
          ),
        ),
      );
    });
    item('put File', () async {
      await _put(
        'file',
        SdbNativeValue(
          web.File(
            ['Hello File'.toJS].toJS,
            'hello.txt',
            web.FilePropertyBag(type: 'text/plain'),
          ),
        ),
      );
    });
    item('put CryptoKey (not extractable) and an encrypted text', () async {
      var subtle = web.window.crypto.subtle;
      var key =
          await subtle
                  .generateKey(
                    (JSObject()
                      ..['name'] = 'AES-GCM'.toJS
                      ..['length'] = 256.toJS),
                    false,
                    ['encrypt'.toJS, 'decrypt'.toJS].toJS,
                  )
                  .toDart
              as web.CryptoKey;
      var iv = Uint8List(12);
      web.window.crypto.getRandomValues(iv.toJS);
      var encrypted =
          await subtle
                  .encrypt(_aesGcm(iv), key, utf8.encode('Secret text').toJS)
                  .toDart
              as JSArrayBuffer;
      await _put('crypto', {
        'key': SdbNativeValue(key),
        'iv': SdbBlob(iv),
        'encrypted': SdbBlob(encrypted.toDart.asUint8List()),
      });
    });
    item('decrypt with the stored CryptoKey', () async {
      var model = await _get('crypto') as SdbModel?;
      if (model == null) {
        write('nothing stored, put a CryptoKey first');
        return;
      }
      var key = (model['key'] as SdbNativeValue).jsObject as web.CryptoKey;
      var decrypted =
          await web.window.crypto.subtle
                  .decrypt(
                    _aesGcm((model['iv'] as SdbBlob).bytes),
                    key,
                    (model['encrypted'] as SdbBlob).bytes.toJS,
                  )
                  .toDart
              as JSArrayBuffer;
      write('decrypted: ${utf8.decode(decrypted.toDart.asUint8List())}');
    });
    item('put OPFS file handle', () async {
      await _put('opfs_file', SdbNativeValue(await _opfsFileHandle()));
    });
    item('put OPFS directory handle', () async {
      await _put(
        'opfs_directory',
        SdbNativeValue(
          await web.window.navigator.storage.getDirectory().toDart,
        ),
      );
    });
    item('put picked file handle (Chromium)', () async {
      var handles = (await _showOpenFilePicker().toDart).toDart;
      await _put('picked_file', SdbNativeValue(handles.first));
    });
    item('put picked directory handle (Chromium)', () async {
      var handle = await _showDirectoryPicker().toDart;
      await _put('picked_directory', SdbNativeValue(handle));
    });
    item('put model with native values', () async {
      await _put('model', {
        'name': 'test',
        'timestamp': SdbTimestamp.now(),
        'blob': SdbNativeValue(web.Blob(['Hello model'.toJS].toJS)),
        'handles': [SdbNativeValue(await _opfsFileHandle())],
      });
    });
    item('read all (after a reload too)', () async {
      var records = await _withDb((db) => _store.findRecords(db));
      if (records.isEmpty) {
        write('empty');
      }
      for (var record in records) {
        write('${record.key}: ${await _describe(record.value)}');
      }
    });
    item('query permission of the handles', () async {
      for (var (key, handle) in await _handles()) {
        write('$key ${_handleName(handle)}: ${await _queryPermission(handle)}');
      }
    });
    item('request read permission of the handles', () async {
      // A user gesture (this click) is needed to prompt.
      for (var (key, handle) in await _handles()) {
        write(
          '$key ${_handleName(handle)}: ${await _requestPermission(handle)}',
        );
      }
    });
    item('export (Blob bytes, handle names, others dropped)', () async {
      var lines = await _withDb(
        (db) => sdbExportDatabaseLines(
          db,
          nativeValueEncoder: (context) async {
            var jsObject = context.value.jsObject as JSObject;
            if (jsObject.instanceOfString('Blob')) {
              // File too.
              var buffer = await (jsObject as web.Blob).arrayBuffer().toDart;
              return buffer.toDart.asUint8List();
            } else if (jsObject.instanceOfString('FileSystemHandle')) {
              return {'handle': (jsObject as web.FileSystemHandle).name};
            }
            return SdbExportNativeValue.drop;
          },
        ),
      );
      for (var line in lines) {
        write(_short(jsonEncode(line)));
      }
    });
    item('delete database', () async {
      await sdbFactoryWeb.deleteDatabase(_dbName);
      write('deleted $_dbName');
    });
    item('memory factory keeps native values', () async {
      var db = await _openDb(newSdbFactoryMemory());
      try {
        var blob = web.Blob();
        await _store.record('blob').put(db, SdbNativeValue(blob));
        var value = await _store.record('blob').getValue(db);
        write(
          'same blob: ${identical((value as SdbNativeValue).jsObject, blob)}',
        );
      } finally {
        await db.close();
      }
    });
  });
}
