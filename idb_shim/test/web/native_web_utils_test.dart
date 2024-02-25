@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:idb_shim/src/native_web/js_utils.dart';
import 'package:test/test.dart';

void main() {
  group('native_web_utils', () {
    test('JSArray', () {
      var jsArray = [1.toJS].toJS;
      expect(jsArray.isJSArray, isTrue);
      expect(jsArray.isJSArrayBuffer, isFalse);
      expect(jsArray.isJSObject, isTrue);
      var dartList = jsArray.dartifyValue();
      expect(dartList, isA<List>());
      expect(dartList, isNot(isA<Uint8List>()));
      expect(dartList, [1]);

      var jsArrayFromDart = dartList.jsifyValue();
      expect(jsArrayFromDart.isJSArray, isTrue);
      expect(jsArrayFromDart.isJSArrayBuffer, isFalse);
      expect(jsArrayFromDart.isJSObject, isTrue);

      /// Compare with dartify()
      dartList = jsArray.dartify()!;
      expect(dartList, isA<List>());
      expect(dartList, isNot(isA<Uint8List>()));
      expect(dartList, [1]);
    });
    test('JSDate', () async {
      var jsDate = JSDate(1);
      expect(jsDate.toISOString(), '1970-01-01T00:00:00.001Z');
      expect(jsDate.getTime(), 1);
      expect(jsDate.isJSDate, isTrue);
      expect(jsDate.isJSObject, isTrue);
      var dartDate = jsDate.dartifyValue();
      expect(dartDate, isA<DateTime>());
      expect(dartDate, DateTime.fromMillisecondsSinceEpoch(1, isUtc: true));
      var jsDateFromDart = dartDate.jsifyValue() as JSDate;
      expect(jsDateFromDart.toISOString(), '1970-01-01T00:00:00.001Z');
      expect(jsDateFromDart.getTime(), 1);
      expect(jsDateFromDart.isJSDate, isTrue);
      expect(jsDateFromDart.isJSObject, isTrue);
    });
    test('JSString', () {
      var jsString = 'test'.toJS;
      expect(jsString.isJSString, isTrue);
      var dartString = jsString.dartifyValue();
      expect(dartString, isA<String>());
      expect(dartString, 'test');
      var jsStringFromDart = dartString.jsifyValue() as JSString;
      expect(jsStringFromDart.toDart, 'test');
      // Same as dartify
      dartString = jsString.dartify()!;
      expect(dartString, isA<String>());
      expect(dartString, 'test');
    });
    test('JSNumber(int)', () {
      var jsNumber = 1.toJS;
      expect(jsNumber.isJSNumber, isTrue);
      var dartNumber = jsNumber.dartifyValue();
      expect(dartNumber, isA<int>());
      expect(dartNumber, 1);
      var jsNumberFromDart = dartNumber.jsifyValue() as JSNumber;
      expect(jsNumberFromDart.toDartInt, 1);
// Same as dartify
      dartNumber = jsNumber.dartify()!;
      expect(dartNumber, isA<int>());
    });
    test('JSNumber(double)', () {
      var jsNumber = 1.5.toJS;
      expect(jsNumber.isJSNumber, isTrue);
      var dartNumber = jsNumber.dartifyValue();
      expect(dartNumber, isA<double>());
      expect(dartNumber, 1.5);
      var jsNumberFromDart = dartNumber.jsifyValue() as JSNumber;
      expect(jsNumberFromDart.toDartDouble, 1.5);
// Same as dartify
      dartNumber = jsNumber.dartify()!;
      expect(dartNumber, isA<double>());
    });
    test('JSBoolean', () {
      var jsBoolean = true.toJS;
      expect(jsBoolean.isJSBoolean, isTrue);
      var dartBoolean = jsBoolean.dartifyValue();
      expect(dartBoolean, isA<bool>());
      expect(dartBoolean, true);
      var jsBooleanFromDart = dartBoolean.jsifyValue() as JSBoolean;
      expect(jsBooleanFromDart.toDart, true);
// Same as dartify
      dartBoolean = jsBoolean.dartify()!;
      expect(dartBoolean, isA<bool>());
      expect(dartBoolean, true);
    });
    test('JSArrayBuffer', () {
      var jsArrayBuffer = Uint8List.fromList([1]).buffer.toJS;
      expect(jsArrayBuffer.isJSObject, isTrue);
      expect(jsArrayBuffer.isJSArrayBuffer, isTrue);
      expect(jsArrayBuffer.isJSArray, isFalse);

      var dartList = jsArrayBuffer.dartifyValue();
      expect(dartList, isA<List>());
      expect(dartList, isA<Uint8List>());
      expect(dartList, [1]);

      var jsArrayBufferFromDart = dartList.jsifyValue();
      expect(jsArrayBufferFromDart.isJSArrayBuffer, isTrue);
      expect(jsArrayBufferFromDart.isJSArray, isFalse);
      expect(jsArrayBufferFromDart.isJSObject, isTrue);

      // Compare with dartify()
      dartList = jsArrayBuffer.dartify()!;
      expect(dartList, isNot(isA<List>()));
    });
    test('JSObject', () {
      var jsObject = {'test': 1}.jsify()!;
      expect(jsObject.isJSObject, isTrue);
      var dartMap = jsObject.dartifyValue();
      expect(dartMap, isA<Map>());
      expect(dartMap, {'test': 1});

      var jsObjectFromDart = dartMap.jsifyValue();
      expect(jsObjectFromDart.isJSObject, isTrue);

      /// Compare with dartify()
      dartMap = jsObject.dartify()!;
      expect(dartMap, isA<Map>());
      expect(dartMap, {'test': 1});
    });

    test('All types', () {
      var list = [
        null,
        true,
        1,
        1.2,
        'text',
        DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        Uint8List.fromList([1, 2, 3]),
        {
          'test': [
            [1, null],
            {
              'sub': [
                [
                  [1],
                  [2, 1]
                ],
                [null],
                'text'
              ]
            }
          ],
          'testBytes': Uint8List.fromList([1, 2, 3]),
          'testDate': DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        }
      ];
      expect(list.jsifyValue().dartifyValue(), list);
    });
  });
}
