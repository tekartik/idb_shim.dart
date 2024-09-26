// https://dart.googlecode.com/svn/branches/bleeding_edge/dart/tests/html/utils.dart
library;

import 'dart:typed_data';

import 'package:dev_test/test.dart';

/// Verifies that [actual] has the same graph structure as [expected].
/// Detects cycles and DAG structure in Maps and Lists.
void verifyGraph(Object? expected, Object? actual) {
  var eItems = <Object?>[];
  var aItems = <Object?>[];

  String message(String path, String reason) =>
      path == '' ? reason : 'path: $path, $reason';

  void walk(String path, Object? expected, Object? actual) {
    if (expected is String || expected is num || expected == null) {
      expect(actual, equals(expected), reason: message(path, 'not equal'));
      return;
    }

    // Cycle or DAG?
    for (var i = 0; i < eItems.length; i++) {
      if (identical(expected, eItems[i])) {
        expect(actual, same(aItems[i]),
            reason: message(path, 'missing back or side edge'));
        return;
      }
    }
    for (var i = 0; i < aItems.length; i++) {
      if (identical(actual, aItems[i])) {
        expect(expected, same(eItems[i]),
            reason: message(path, 'extra back or side edge'));
        return;
      }
    }
    eItems.add(expected);
    aItems.add(actual);

//    if (expected is Blob) {
//      expect(actual is Blob, isTrue,
//          reason: '$actual is Blob');
//      expect(expected.type, equals(actual.type),
//          reason: message(path, '.type'));
//      expect(expected.size, equals(actual.size),
//          reason: message(path, '.size'));
//      return;
//    }

    if (expected is ByteBuffer) {
      expect(actual is ByteBuffer, isTrue, reason: '$actual is ByteBuffer');
      expect(
          expected.lengthInBytes, equals((actual as ByteBuffer).lengthInBytes),
          reason: message(path, '.lengthInBytes'));
      // TODO(antonm): one can create a view on top of those
      // and check if contents identical.  Let's do it later.
      return;
    }

    if (expected is DateTime) {
      expect(actual is DateTime, isTrue, reason: '$actual is DateTime');
      expect(expected.millisecondsSinceEpoch,
          equals((actual as DateTime).millisecondsSinceEpoch),
          reason: message(path, '.millisecondsSinceEpoch'));
      return;
    }

//    if (expected is ImageData) {
//      expect(actual is ImageData, isTrue,
//          reason: '$actual is ImageData');
//      expect(expected.width, equals(actual.width),
//          reason: message(path, '.width'));
//      expect(expected.height, equals(actual.height),
//          reason: message(path, '.height'));
//      walk('$path.data', expected.data, actual.data);
//      return;
//    }

    if (expected is TypedData) {
      expect(actual is TypedData, isTrue, reason: '$actual is TypedData');
      walk('$path/.buffer', expected.buffer, (actual as TypedData).buffer);
      expect(expected.offsetInBytes, equals(actual.offsetInBytes),
          reason: message(path, '.offsetInBytes'));
      expect(expected.lengthInBytes, equals(actual.lengthInBytes),
          reason: message(path, '.lengthInBytes'));
      // And also fallback to elements check below.
    }

    if (expected is List) {
      expect(actual, isList, reason: message(path, '$actual is List'));
      expect((actual as List).length, expected.length,
          reason: message(path, 'different list lengths'));
      for (var i = 0; i < expected.length; i++) {
        walk('$path[$i]', expected[i], actual[i]);
      }
      return;
    }

    if (expected is Map) {
      expect(actual, isMap, reason: message(path, '$actual is Map'));
      for (var key in expected.keys) {
        if (!(actual as Map).containsKey(key)) {
          expect(false, isTrue, reason: message(path, "missing key '$key'"));
        }
        walk("$path['$key']", expected[key], actual[key]);
      }
      for (var key in (actual as Map).keys) {
        if (!expected.containsKey(key)) {
          expect(false, isTrue, reason: message(path, "extra key '$key'"));
        }
      }
      return;
    }

    expect(false, isTrue, reason: 'Unhandled type: $expected');
  }

  walk('', expected, actual);
}
