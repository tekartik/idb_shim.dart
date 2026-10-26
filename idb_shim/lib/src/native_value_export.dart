import 'dart:async';
import 'dart:typed_data';

import 'package:idb_shim/src/native_value.dart';

/// Sentinel values returned by an [IdbExportNativeValueEncoder].
abstract final class IdbExportNativeValue {
  /// Drops the map entry or the list item holding the native value (the next
  /// items of the list shift), or the record when the native value is the
  /// record value.
  static const Object drop = _IdbExportNativeValueSentinel('drop');

  /// Drops the record holding the native value.
  static const Object dropRecord = _IdbExportNativeValueSentinel('dropRecord');
}

class _IdbExportNativeValueSentinel {
  const _IdbExportNativeValueSentinel(this.name);

  final String name;

  @override
  String toString() => 'IdbExportNativeValue.$name';
}

/// A native value met by an export.
class IdbExportNativeValueContext {
  IdbExportNativeValueContext._(
    this.storeName,
    this.key,
    this.path,
    this.value,
  );

  /// The store name.
  final String storeName;

  /// The record key.
  final Object key;

  /// The path of [value] in the record value: map keys (String) and list
  /// indexes (int), empty when [value] is the record value.
  final List<Object> path;

  /// The native value.
  final IdbNativeValue value;

  @override
  String toString() =>
      'native value $value in store $storeName key $key path $path';
}

/// Converts a native value met by an export, a native value cannot be
/// exported as is.
///
/// It returns the value to export in its place (any value the export
/// supports, `null` included), [IdbExportNativeValue.drop] or
/// [IdbExportNativeValue.dropRecord]. When the native value is the record
/// value, `null` drops the record (a record value cannot be null). An error
/// thrown stops the export.
///
/// Called once the records are read, it can be asynchronous (e.g. to read
/// the bytes of a JS `Blob`).
typedef IdbExportNativeValueEncoder =
    FutureOr<Object?> Function(IdbExportNativeValueContext context);

/// The default encoder: a native value cannot be exported.
Object? _rejectNativeValue(IdbExportNativeValueContext context) =>
    throw ArgumentError.value(
      context.value,
      null,
      'Cannot export the $context, use a nativeValueEncoder',
    );

/// Thrown to drop the record being converted.
class _DropRecord implements Exception {
  const _DropRecord();
}

/// Converts the native values of a record value for an export.
class IdbNativeValueExportConverter {
  /// Without [encoder], a native value cannot be exported.
  IdbNativeValueExportConverter(
    this.storeName,
    this.key,
    IdbExportNativeValueEncoder? encoder,
  ) : encoder = encoder ?? _rejectNativeValue;

  /// The store name.
  final String storeName;

  /// The record key.
  final Object key;

  /// The encoder.
  final IdbExportNativeValueEncoder encoder;

  /// True if [value] holds a native value.
  static bool hasNativeValue(Object? value) {
    if (value is IdbNativeValue) {
      return true;
    } else if (value is Map) {
      return value.values.any(hasNativeValue);
    } else if (value is List && value is! Uint8List) {
      return value.any(hasNativeValue);
    }
    return false;
  }

  /// The converted record value, null to drop the record.
  Future<Object?> convertRecordValue(Object value) async {
    try {
      var converted = await _convert(value, const []);
      if (converted == null ||
          identical(converted, IdbExportNativeValue.drop)) {
        return null;
      }
      return converted;
    } on _DropRecord {
      return null;
    }
  }

  /// The converted value, [IdbExportNativeValue.drop] to drop it.
  Future<Object?> _convert(Object? value, List<Object> path) async {
    if (value is IdbNativeValue) {
      var converted = await encoder(
        IdbExportNativeValueContext._(
          storeName,
          key,
          List.unmodifiable(path),
          value,
        ),
      );
      if (identical(converted, IdbExportNativeValue.dropRecord)) {
        throw const _DropRecord();
      }
      return converted;
    } else if (!hasNativeValue(value)) {
      return value;
    } else if (value is Map) {
      var map = <String, Object?>{};
      for (var entry in value.entries) {
        var key = entry.key as String;
        var converted = await _convert(entry.value, [...path, key]);
        if (!identical(converted, IdbExportNativeValue.drop)) {
          map[key] = converted;
        }
      }
      return map;
    } else {
      var list = <Object?>[];
      var items = value as List;
      for (var i = 0; i < items.length; i++) {
        var converted = await _convert(items[i], [...path, i]);
        if (!identical(converted, IdbExportNativeValue.drop)) {
          list.add(converted);
        }
      }
      return list;
    }
  }
}
