import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:idb_shim/src/utils/env_utils.dart';

/// Get object keys
/// @deprecated
JSArray<JSString> jsObjectKeys(JSObject object) => _jsObjectKeys(object);

@JS('Object.keys')
external JSArray<JSString> _jsObjectKeys(JSAny object);

/// The Object.getOwnPropertyNames() static method returns an array
/// of all properties (including non-enumerable properties except
/// for those which use Symbol) found directly in a given object.
@JS('Object.getOwnPropertyNames')
external JSArray<JSString> _jsGetOwnPropertyNames(JSAny object);

/// JavaScript Object extension
extension JSObjectKeysExtension on JSAny {
  /// Convert to Dart List
  List<String> getOwnPropertyNames() {
    return _jsGetOwnPropertyNames(this).toDartList();
  }

  /// Convert to Dart List
  List<String> keys() {
    return _jsObjectKeys(this).toDartList();
  }
}

/// JavaScript Date
@JS('Date')
extension type JSDate._(JSObject _) implements JSObject {
  /// Create a JavaScript date object
  external JSDate(int value);
}

/// JavaScript Date extension
extension JSDateExtension on JSDate {
  /// Convert JavaScript date object to ISO string
  external String toISOString();

  /// Convert JavaScript date object to milliseconds since epoch
  external int getTime();
}

/// JavaScript Array extension.
extension JSArrayExtension on JSArray {
  /// Get the length of the array
  @JS('length')
  external int get idbShimLength;
}

/// Convert to a dart string list
extension JSArrayStringConversion on JSArray<JSString> {
  /// Convert to Dart `List<String>`
  List<String> toDartList() {
    return toDart.map((e) => e.toDart).toList();
  }
}

/// JavaScript helpers
extension JSAnyExtension on JSAny {
  /// True if it is a Javascript date object
  bool get isJSDate {
    return instanceOfString('Date');
  }

  /// True if it is a Javascript array object
  bool get isJSArray {
    return instanceOfString('Array');
  }

  /// True if it is a Javascript array buffer object
  bool get isJSArrayBuffer {
    return instanceOfString('ArrayBuffer');
  }

  /// True if it is a Javascript uint8 buffer object
  bool get isJSUint8Array {
    return instanceOfString('Uint8Array');
  }

  /// Could be an array or a data!
  bool get isJSObject {
    return typeofEquals('object');
  }

  /// True if it is a Javascript string object
  bool get isJSString {
    return typeofEquals('string');
  }

  /// True if it is a Javascript number object
  bool get isJSNumber {
    return typeofEquals('number');
  }

  /// True if it is a Javascript boolean object
  bool get isJSBoolean {
    return typeofEquals('boolean');
  }
}

/// jsify helper for Dart objects (handle Uint8List, DateTime, Map, List, String, num, bool)
extension IDBJsifyExtension on Object {
  /// Convert Dart object to JavaScript object
  JSAny jsifyValue() {
    // Bug in DateTime that requires this
    // hack (or drop support for DateTime)
    return jsifyValueStrict();
  }

  /// Convert a key (assuming not a date or Uint8List) to a JavaScript object
  JSAny jsifyKey() {
    return jsify()!;
  }

  /// Convert Dart object to JavaScript object
  JSAny jsifyValueStrict() {
    var value = this;
    if (value is String) {
      return value.toJS;
    } else if (value is num) {
      return value.toJS;
    } else if (value is Map) {
      var jsObject = JSObject();
      value.forEach((key, value) {
        jsObject[(key as String)] = (value as Object?)?.jsifyValueStrict();
      });
      return jsObject;
    } else if (value is List) {
      if (value is Uint8List) {
        return value.toJS; // value.buffer.toJS;
      }
      var jsArray = JSArray.withLength(value.length);
      for (var (i, item) in value.indexed) {
        jsArray.setProperty(i.toJS, (item as Object?)?.jsifyValueStrict());
      }
      return jsArray;
    } else if (value is DateTime) {
      return JSDate((this as DateTime).millisecondsSinceEpoch);
    } else if (value is bool) {
      return value.toJS;
    }
    throw UnsupportedError(
      'Unsupported value: $value (type: ${value.runtimeType})',
    );
  }
}

/// See https://github.com/dart-lang/sdk/issues/55203#issuecomment-2003246663
num wasmDartifyNum(JSNumber value) {
  final jsDouble = value.toDartDouble;
  final jsInt = jsDouble.truncate();
  return (jsInt.toDouble() == jsDouble) ? jsInt : jsDouble;
}

/// In JS everything is a double.
num jsDartifyNum(JSNumber value) {
  return value.toDartDouble;
}

/// JavaScript number extension.
extension IdbJSNumberExt on JSNumber {
  /// Convert JavaScript number to Dart number
  /// /// See https://github.com/dart-lang/sdk/issues/55203#issuecomment-2003246663
  num get toDartNum =>
      idbIsRunningAsJavascript ? jsDartifyNum(this) : wasmDartifyNum(this);
}

/// dartify helper for JavaScript objects (handle Uint8List, DateTime, Map, List, String, num, bool)
extension IDBDartifyExtension on JSAny {
  /// Convert JavaScript object to Dart object
  Object dartifyValue() {
    /// When running as wasm strict is necessary
    return dartifyValueStrict();
  }

  /// Convert JavaScript object to Dart object
  Object dartifyKey() {
    /// When running as wasm strict is necessary
    return dartifyValueStrict();
  }

  /// Convert a js value to [String] or `[List<String>]`
  Object dartifyStringOrStringList() {
    // devPrint('dartifyStringOrStringList: $this');
    var value = this;
    if (value.isJSString) {
      return (value as JSString).toDart;
    } else if (value.isJSArray) {
      return (value as JSArray).toDart.map((e) {
        return (e as JSAny).dartifyKeyPath();
      }).toList();
    }

    throw UnsupportedError(
      'Unsupported keyPath: $value (type: ${value.runtimeType})',
    );
  }

  /// Convert keyPath to [String] or [`List<String>`]
  Object dartifyKeyPath() => dartifyStringOrStringList();

  /// Convert JavaScript object to Dart object
  Object dartifyValueStrict() {
    var value = this;
    if (value.isA<JSString>()) {
      return (value as JSString).toDart;
    } else if (value.isA<JSNumber>()) {
      return (value as JSNumber).toDartNum;
    } else if (value.isA<JSBoolean>()) {
      return (value as JSBoolean).toDart;
    } else if (value.isJSObject) {
      if (value.isA<JSArray>()) {
        var jsArray = value as JSArray;
        var list = List.generate(
          jsArray.idbShimLength,
          (index) => jsArray.getProperty(index.toJS)?.dartifyValueStrict(),
        );
        return list;
      } else if (value.isA<JSDate>()) {
        return DateTime.fromMillisecondsSinceEpoch(
          (value as JSDate).getTime(),
          isUtc: true,
        );
      } else if (value.isA<JSArrayBuffer>()) {
        return (value as JSArrayBuffer).toDart.asUint8List();
      } else if (value.isA<JSUint8Array>()) {
        return (value as JSUint8Array).toDart;
      }
      try {
        var jsObject = value as JSObject;
        var object = <String, Object?>{};
        var keys = jsObjectKeys(jsObject).toDart;
        for (var key in keys) {
          object[key.toDart] = jsObject.getProperty(key)?.dartifyValueStrict();
        }
        return object;
      } catch (_) {
        // Compat, old jsify might convert to DateTime
        // ignore: invalid_runtime_check_with_js_interop_types
        if (value is DateTime) {
          return value;
        }
      }
    }
    throw UnsupportedError(
      'Unsupported value: $value (type: ${value.runtimeType})',
    );
  }
}

/// Generic JSError
extension type JSError._(JSObject _) implements JSObject {}

/// Generic indexed DB/Javascript error.
extension JSErrorExt on JSError {
  /// Get the error message
  external String? get message;

  /// Get the error message
  external String? get name;
}
