import 'dart:convert';

import 'package:idb_shim/src/native_value.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/utils/type_adapter.dart';

/// Rejects the conversion of an [IdbNativeValue] (export, json storage).
class _IdbNativeValueRejectConverter<S, T> extends Converter<S, T> {
  @override
  T convert(S input) =>
      throw ArgumentError.value(input, null, 'IdbNativeValue not encodable');
}

/// Lets sembast accept an [IdbNativeValue] (it only accepts the types of its
/// codec), it cannot be encoded.
class _IdbNativeValueAdapter
    extends SembastTypeAdapter<IdbNativeValue, Object> {
  @override
  String get name => 'IdbNativeValue';

  @override
  bool isType(Object? value) => value is IdbNativeValue;

  @override
  final Converter<IdbNativeValue, Object> encoder =
      _IdbNativeValueRejectConverter<IdbNativeValue, Object>();

  @override
  final Converter<Object, IdbNativeValue> decoder =
      _IdbNativeValueRejectConverter<Object, IdbNativeValue>();
}

/// Codec of the memory (no storage) sembast databases: the default one plus
/// [IdbNativeValue] kept as is.
final sembastCodecWithIdbNativeValue = sembast.SembastCodec(
  signature: null,
  codec: null,
  jsonEncodableCodec: JsonEncodableCodec(
    adapters: [...sembastDefaultTypeAdapters, _IdbNativeValueAdapter()],
  ),
);
