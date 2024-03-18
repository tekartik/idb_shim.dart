import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Get object keys
@JS('Object.keys')
external JSArray jsObjectKeys(JSObject object);

/// JavaScript Date
@JS('Date')
extension type JSDate._(JSObject _) implements JSObject {
  /// Create a JavaScript date object
  external JSDate(int value);

  /// Convert JavaScript date object to ISO string
  external String toISOString();

  /// Convert JavaScript date object to milliseconds since epoch
  external int getTime();
}

/// JavaScript Array extension.
extension JSArrayExtension on JSArray {
  /// Get the length of the array
  external int get length;
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
// Bug in DateTime that requires this hack (or drop support for DateTime)
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
        'Unsupported value: $value (type: ${value.runtimeType})');
  }
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

  /// Convert JavaScript object to Dart object
  Object dartifyValueStrict() {
    var value = this;
    if (value.isJSString) {
      return (value as JSString).toDart;
    } else if (value.isJSNumber) {
      try {
// toDartInt throws if it is not an integer
        return (value as JSNumber).toDartInt;
      } catch (_) {
        return (value as JSNumber).toDartDouble;
      }
    } else if (value.isJSBoolean) {
      return (value as JSBoolean).toDart;
    } else if (value.isJSObject) {
      if (value.isJSArray) {
        var jsArray = value as JSArray;
        var list = List.generate(jsArray.length,
            (index) => jsArray.getProperty(index.toJS)?.dartifyValueStrict());
        return list;
      } else if (value.isJSDate) {
        return DateTime.fromMillisecondsSinceEpoch((value as JSDate).getTime(),
            isUtc: true);
      } else if (value.isJSArrayBuffer) {
        return (value as JSArrayBuffer).toDart.asUint8List();
      } else if (value.isJSUint8Array) {
        return (value as JSUint8Array).toDart;
      }
      try {
        var jsObject = value as JSObject;
        var object = <String, Object?>{};
        var keys = jsObjectKeys(jsObject).toDart;
        for (var key in keys) {
          object[(key as JSString).toDart] =
              jsObject.getProperty(key)?.dartifyValueStrict();
        }
        return object;
      } catch (_) {
// Special handling of js dartified value issue for DateTime
// jisify concert a DateTime as is...
        if (value is DateTime) {
          return value;
        }
      }
    }
    throw UnsupportedError(
        'Unsupported value: $value (type: ${value.runtimeType})');
  }
}
