/// A browser object stored as is (structured clone) by the native factory,
/// such as a `FileSystemFileHandle`, a `FileSystemDirectoryHandle`, a `Blob`,
/// a `File` or a `CryptoKey`.
///
/// Values are converted from/to plain values (null, bool, num, String, List,
/// Map, DateTime, Uint8List). Any other JS object must be wrapped in an
/// [IdbNativeValue] to be stored, alone or inside a map or a list. Reading
/// returns an [IdbNativeValue] for each JS object that is not a plain object,
/// an array, a date or a binary buffer.
///
/// ```dart
/// await store.put(IdbNativeValue(fileHandle), 'last');
/// var value = await store.getObject('last') as IdbNativeValue;
/// var handle = value.jsObject as FileSystemFileHandle;
/// ```
///
/// Only supported by the native (browser) factory and the memory factories
/// (`idbFactoryMemory`, `newIdbFactoryMemory()`), the memory ones keeping the
/// value itself (no copy). The factories with a storage (io, sqflite,
/// `idbFactoryMemoryFs`) reject such values, so does an export unless a
/// `nativeValueEncoder` converts them (`idbExportDatabase`,
/// `idbExportDatabaseLines`, `sdbExportDatabaseLines`). The browser
/// throws a `DataCloneError` for an object it cannot serialize (e.g. a
/// `FileSystemHandle` in browsers that do not support storing it).
class IdbNativeValue {
  /// Wraps [jsObject], a JS object (any interop binding works,
  /// `package:web`, raw `dart:js_interop`...).
  IdbNativeValue(this.jsObject);

  /// The JS object.
  final Object jsObject;

  @override
  String toString() => 'IdbNativeValue($jsObject)';
}
