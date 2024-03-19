@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:idb_shim/src/native_web/js_utils.dart';
import 'package:test/test.dart';

void main() {
  group('native_web_utils', () {
    test('null', () {
      expect(null.jsify()?.dartifyValueStrict(), null);
    });
    test('JSArray', () {
      var jsArray = [1.toJS].toJS;
      expect(jsArray.isJSArray, isTrue);
      expect(jsArray.isJSArrayBuffer, isFalse);
      expect(jsArray.isJSObject, isTrue);
      var dartList = jsArray.dartifyValueStrict();
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
      var dartDate = jsDate.dartifyValueStrict();
      expect(dartDate, isA<DateTime>());
      expect(dartDate, DateTime.fromMillisecondsSinceEpoch(1, isUtc: true));

      var jsDateFromDart = dartDate.jsifyValueStrict() as JSDate;
      expect(jsDateFromDart.toISOString(), '1970-01-01T00:00:00.001Z');
      expect(jsDateFromDart.getTime(), 1);
      expect(jsDateFromDart.isJSDate, isTrue);
      expect(jsDateFromDart.isJSObject, isTrue);

      jsDateFromDart = dartDate.jsifyValue() as JSDate;
      expect(jsDateFromDart.toISOString(), '1970-01-01T00:00:00.001Z');
      expect(jsDateFromDart.getTime(), 1);
      expect(jsDateFromDart.isJSDate, isTrue);
      expect(jsDateFromDart.isJSObject, isTrue);

      // Temp bug!
      try {
        var rawJisifiedDateTime = dartDate.jsify();
        expect(rawJisifiedDateTime, isA<DateTime>());
        // ignore: avoid_print
        print(
            'rawJisifiedDateTime: $rawJisifiedDateTime ${rawJisifiedDateTime.runtimeType}');
      } catch (e) {
        // ignore: avoid_print
        print('Temp DateTime().jisify bug fixed: $e');
      }

      // Compare with dartify()! same as dartifyValue
      dartDate = jsDate.dartify()!;
      //print('dartDate: $dartDate');
      expect(dartDate, isA<DateTime>());
      expect(dartDate, DateTime.fromMillisecondsSinceEpoch(1, isUtc: true));
    });
    test('JSString', () {
      var jsString = 'test'.toJS;
      expect(jsString.isJSString, isTrue);
      var dartString = jsString.dartifyValueStrict();
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
      var dartNumber = jsNumber.dartifyValueStrict();
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
      var dartNumber = jsNumber.dartifyValueStrict();
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
      var dartBoolean = jsBoolean.dartifyValueStrict();
      expect(dartBoolean, isA<bool>());
      expect(dartBoolean, true);
      var jsBooleanFromDart = dartBoolean.jsifyValue() as JSBoolean;
      expect(jsBooleanFromDart.toDart, true);
// Same as dartify
      dartBoolean = jsBoolean.dartify()!;
      expect(dartBoolean, isA<bool>());
      expect(dartBoolean, true);
    });
    // no longer supported.
    test('JSArrayBuffer', () {
      var jsArrayBuffer = Uint8List.fromList([1]).buffer.toJS;
      expect(jsArrayBuffer.isJSObject, isTrue);
      expect(jsArrayBuffer.isJSArrayBuffer, isTrue);
      expect(jsArrayBuffer.isJSArray, isFalse);

      var dartList = jsArrayBuffer.dartifyValueStrict();
      expect(dartList, isA<List>());
      expect(dartList, isA<Uint8List>());
      expect(dartList, [1]);

      // Compare with dartify()
      dartList = jsArrayBuffer.dartify()!;
      expect(dartList, isNot(isA<List>()));
    });
    test('JSUint8Array', () {
      var jsUint8Array = Uint8List.fromList([1]).toJS;
      expect(jsUint8Array.isJSObject, isTrue);
      expect(jsUint8Array.isJSUint8Array, isTrue);
      expect(jsUint8Array.isJSArrayBuffer, isFalse);
      expect(jsUint8Array.isJSArray, isFalse);

      var dartList = jsUint8Array.dartifyValueStrict();
      expect(dartList, isA<List>());
      expect(dartList, isA<Uint8List>());
      expect(dartList, [1]);

      var jsUint8ArrayFromDart = dartList.jsifyValue();
      expect(jsUint8ArrayFromDart.isJSArrayBuffer, isFalse);
      expect(jsUint8ArrayFromDart.isJSUint8Array, isTrue);
      expect(jsUint8ArrayFromDart.isJSArray, isFalse);
      expect(jsUint8ArrayFromDart.isJSObject, isTrue);

      // Compare with dartify()
      dartList = jsUint8Array.dartify()!;
      expect(dartList, isA<List>());
      expect(dartList, isA<Uint8List>());
      expect(dartList, [1]);
    });
    test('JSObject', () {
      var jsObject = {'test': 1}.jsify()!;
      expect(jsObject.isJSObject, isTrue);
      var dartMap = jsObject.dartifyValueStrict();
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
                  [2, 1],
                  {'sub2': 1}
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
      expect(list.jsify()?.dartifyValueStrict(), list);
      expect(list.jsify().dartify(), list);
      expect(list.jsifyValueStrict().dartifyValueStrict(), list);
      expect(list.jsifyValueStrict().dartify(), list);
    });

    test('dartifyNum', () {
      var jsInt = 1.toJS;
      var jsDouble = 1.5.toJS;
      var dartInt = jsDartifyNum(jsInt);
      var dartDouble = jsDartifyNum(jsDouble);
      var dartWasmInt = wasmDartifyNum(jsInt);
      var dartWasmDouble = wasmDartifyNum(jsDouble);
      var dartAnyInt = jsInt.toDartNum;
      var dartAnyDouble = jsDouble.toDartNum;
      expect(dartInt, 1);
      expect(dartInt, isA<int>());
      expect(dartWasmInt, 1);
      expect(dartWasmInt, isA<int>());
      expect(dartAnyInt, 1);
      expect(dartAnyInt, isA<int>());
      expect(dartDouble, closeTo(1.5, 0.00001));
      expect(dartDouble, isA<double>());
      expect(dartWasmDouble, closeTo(1.5, 0.00001));
      expect(dartWasmDouble, isA<double>());
      expect(dartAnyDouble, closeTo(1.5, 0.00001));
      expect(dartAnyDouble, isA<double>());

      jsInt = 1.0.toJS;
      dartInt = jsDartifyNum(jsInt);
      dartWasmInt = wasmDartifyNum(jsInt);
      dartAnyInt = jsInt.toDartNum;
      expect(dartInt, 1);
      expect(dartInt, isA<int>());
      expect(dartWasmInt, 1);
      expect(dartWasmInt, isA<int>());
      expect(dartAnyInt, 1);
      expect(dartAnyInt, isA<int>());
    });
  });
}
