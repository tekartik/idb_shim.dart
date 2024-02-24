@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';

@JS('Object.keys')
external JSArray jsObjectKeys(JSObject object);

@JS('Date')
extension type JSDate._(JSObject _) implements JSObject {
  external JSDate(int value);
  external String toISOString();
  external int getTime();
}

extension JSArrayExtension on JSArray {
  external int get length;
}

extension JSAnyExtension on JSAny {
  bool get isJSDate {
    return instanceOfString('Date');
  }

  bool get isJSArray {
    return instanceOfString('Array');
  }

  /// Could be an array or a data!
  bool get isJSObject {
    return typeofEquals('object');
  }

  bool get isJSString {
    return typeofEquals('string');
  }

  bool get isJSNumber {
    return typeofEquals('number');
  }

  bool get isJSBoolean {
    return typeofEquals('boolean');
  }
}

extension IDBJsifyExtension on Object {
  JSAny jsifyValue() {
    var value = this;
    if (value is String) {
      return value.toJS;
    } else if (value is num) {
      return value.toJS;
    } else if (value is Map) {
      var jsObject = JSObject();
      value.forEach((key, value) {
        jsObject[(key as String)] = (value as Object?)?.jsifyValue();
      });
    } else if (value is List) {
      var jsArray = JSArray.withLength(value.length);
      for (var (i, item) in value.indexed) {
        jsArray.setProperty(i.toJS, (item as Object?)?.jsifyValue());
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

extension IDBDartifyExtension on JSAny {
  Object dartifyValue() {
    var value = this;
    if (value.isJSString) {
      return (value as JSString).toDart;
    } else if (value.isJSObject) {
      if (value.isJSArray) {
        var jsArray = value as JSArray;
        var list = List.generate(jsArray.length,
            (index) => jsArray.getProperty(index.toJS)?.dartify());
        return list;
      } else if (value.isJSDate) {
        return DateTime.fromMicrosecondsSinceEpoch((value as JSDate).getTime());
      }
      var object = <String, Object?>{};
      var jsObject = value as JSObject;
      var keys = jsObjectKeys(jsObject).toDart;
      for (var key in keys) {
        object[(key as JSString).toDart] = jsObject.getProperty(key)?.dartify();
      }
      return object;
    }
    throw UnsupportedError(
        'Unsupported value: $value (type: ${value.runtimeType})');
  }
}

void main() {
  group('native_web_utils', () {
    test('array', () {
      var jsArray = [1.toJS].toJS;
      expect(jsArray.isJSArray, isTrue);
      expect(jsArray.isJSObject, isTrue);
    });
    test('date', () async {
      var jsDate = JSDate(1);
      expect(jsDate.toISOString(), '1970-01-01T00:00:00.001Z');
      expect(jsDate.getTime(), 1);
      expect(jsDate.isJSDate, isTrue);
      expect(jsDate.isJSObject, isTrue);
    });
    test('string', () {
      var jsString = 'test'.toJS;
      expect(jsString.isJSString, isTrue);
    });
    test('number', () {
      var jsNumber = 1.toJS;
      expect(jsNumber.isJSNumber, isTrue);
      jsNumber = 1.5.toJS;
      expect(jsNumber.isJSNumber, isTrue);
    });
    test('boolean', () {
      var jsBoolean = true.toJS;
      expect(jsBoolean.isJSBoolean, isTrue);
    });
  });
}
