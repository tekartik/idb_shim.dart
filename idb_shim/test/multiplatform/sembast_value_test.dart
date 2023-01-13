library idb_shim.sembast_value_test;

import 'dart:typed_data';

import 'package:idb_shim/src/sembast/sembast_value.dart';
import 'package:sembast/blob.dart';
import 'package:sembast/timestamp.dart';

import '../idb_test_common.dart';

void main() {
  group('sembast_value', () {
    test('allAdapters', () {
      var decoded = {
        'null': null,
        'bool': true,
        'int': 1,
        'list': [1, 2, 3],
        'map': {
          'sub': [1, 2, 3]
        },
        'string': 'text',
        'dateTime': DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        'blob': Uint8List.fromList([1, 2, 3]),
      };
      var encoded = {
        'null': null,
        'bool': true,
        'int': 1,
        'list': [1, 2, 3],
        'map': {
          'sub': [1, 2, 3]
        },
        'string': 'text',
        'dateTime': Timestamp.fromMillisecondsSinceEpoch(1),
        'blob': Blob.fromList([1, 2, 3]),
      };
      expect(toSembastValue(decoded), encoded);
      expect(fromSembastValue(encoded), decoded);
    });

    test('modified', () {
      var identicals = [
        <String, Object?>{},
        1,
        2.5,
        'text',
        true,
        // null, no longer supported with nnbd
        //<Object?, Object?>{},
        <Object?>[],
        [1, null, 3],
        [
          {
            'test': [
              1,
              true,
              [4.5]
            ]
          }
        ],
        <String, Object?>{
          'test': [
            1,
            true,
            [4.5]
          ]
        }
      ];
      for (var value in identicals) {
        var encoded = value;
        encoded = toSembastValue(value);

        expect(identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
        value = fromSembastValue(encoded);
        expect(identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
      }
      var notIdenticals = [
        <Object?, Object?>{}, // being cast
        Uint8List.fromList([1, 2, 3]),
        DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        [DateTime.fromMillisecondsSinceEpoch(1, isUtc: true)],
        <String, Object?>{
          'test': DateTime.fromMillisecondsSinceEpoch(1, isUtc: true)
        },
        <String, Object?>{
          'test': [
            DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
          ]
        }
      ];
      for (var value in notIdenticals) {
        Object? encoded = value;
        encoded = toSembastValue(value);
        expect(fromSembastValue(encoded), value);
        expect(!identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
      }
    });
  });
}
