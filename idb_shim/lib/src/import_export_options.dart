import 'package:idb_shim/src/native_value_export.dart';
import 'package:sembast/utils/sembast_import_export.dart'
    show SembastExportTypeEncoding;

/// How the custom types (DateTime, Uint8List) are encoded in an export:
/// legacy `@` (`{"@Timestamp": ...}`, `{"@Blob": ...}`, the default) or `$`
/// (`{"$Timestamp": ...}`, `{"$Blob": ...}`, the header then has
/// `"type_prefix": "$"`).
typedef IdbExportTypeEncoding = SembastExportTypeEncoding;

/// Options of an idb or sdb export (`idbExportDatabase`,
/// `idbExportDatabaseLines`, `sdbExportDatabaseLines`).
class IdbExportOptions {
  /// Export options.
  const IdbExportOptions({this.nativeValueEncoder, this.typeEncoding});

  /// Converts the native values met, see [IdbExportNativeValueEncoder]. It
  /// overrides the `nativeValueEncoder` argument of the export functions.
  final IdbExportNativeValueEncoder? nativeValueEncoder;

  /// The encoding of the custom types, the legacy `@` one when null, see
  /// [IdbExportTypeEncoding].
  final IdbExportTypeEncoding? typeEncoding;

  /// A copy with the given fields changed.
  IdbExportOptions copyWith({
    IdbExportNativeValueEncoder? nativeValueEncoder,
    IdbExportTypeEncoding? typeEncoding,
  }) => IdbExportOptions(
    nativeValueEncoder: nativeValueEncoder ?? this.nativeValueEncoder,
    typeEncoding: typeEncoding ?? this.typeEncoding,
  );

  @override
  String toString() =>
      'IdbExportOptions(nativeValueEncoder: ${nativeValueEncoder != null}, '
      'typeEncoding: ${typeEncoding?.name})';
}

/// Options of an idb or sdb import (`idbImportDatabase`,
/// `sdbImportDatabase`).
class IdbImportOptions {
  /// Import options.
  const IdbImportOptions({this.allowedTypeEncodings});

  /// The accepted export type encodings (an export without `type_prefix`
  /// being [IdbExportTypeEncoding.at]), all when null. Another one throws a
  /// `FormatException`.
  final List<IdbExportTypeEncoding>? allowedTypeEncodings;

  /// A copy with the given fields changed.
  IdbImportOptions copyWith({
    List<IdbExportTypeEncoding>? allowedTypeEncodings,
  }) => IdbImportOptions(
    allowedTypeEncodings: allowedTypeEncodings ?? this.allowedTypeEncodings,
  );

  @override
  String toString() =>
      'IdbImportOptions(allowedTypeEncodings: '
      '${allowedTypeEncodings?.map((e) => e.name)})';
}
