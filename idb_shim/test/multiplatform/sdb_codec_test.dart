import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_codec.dart' show SdbCodecPrvExt;
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  test('SdbCodec.none', () {
    var codec = SdbCodec.none;
    expect(codec.encode(1), 1);
    expect(codec.encode(SdbTimestamp(1, 2000)), SdbTimestamp(1, 2000));
  });
  test('SdbCodec.defaultCodec', () {
    var codec = SdbCodec.defaultCodec;
    expect(codec.encode(1), 1);
    expect(codec.encode(SdbTimestamp(1, 2000)), {
      r'$Timestamp': '1970-01-01T00:00:01.000002Z',
    });
    expect(
      codec.decode<SdbTimestamp>({
        r'$Timestamp': '1970-01-01T00:00:01.000002Z',
      }),
      SdbTimestamp(1, 2000),
    );
    expect(
      codec.decode<SdbTimestamp>({
        r'@Timestamp': '1970-01-01T00:00:01.000002Z',
      }),
      SdbTimestamp(1, 2000),
    );
  });
  test('SdbNativeValue', () {
    var nativeValue = SdbNativeValue(Object());
    for (var codec in <SdbCodec>[SdbCodec.none, SdbCodec.defaultCodec]) {
      // Stored as is.
      expect(codec.encode(nativeValue), same(nativeValue));
      expect(codec.decode<Object>(nativeValue), same(nativeValue));
      var encoded =
          codec.encode({
                'value': nativeValue,
                'list': [nativeValue],
              })
              as Map;
      expect(encoded['value'], same(nativeValue));
      expect((encoded['list'] as List).first, same(nativeValue));
      var decoded = codec.decode<Map>(encoded);
      expect(decoded['value'], same(nativeValue));
      expect((decoded['list'] as List).first, same(nativeValue));
    }
  });
  group('SdbCodec.defaultCodec escape', () {
    var codec = SdbCodec.defaultCodec;
    Object roundTrip(Object value) => codec.decode<Object>(codec.encode(value));

    test('maps looking like custom types', () {
      for (var value in <Object>[
        {r'$': 'raw'},
        {'@': 'raw'},
        {r'$': <String, Object?>{}},
        {
          r'$': {'a': 1},
        },
        {r'$Timestamp': '1970-01-01T00:00:01.000002Z'},
        {'@Timestamp': '1970-01-01T00:00:01.000002Z'},
        {r'$Blob': 'AQID'},
        {r'$Timestamp': 'not a date'},
        {
          r'$': {r'$': 'raw'},
        },
      ]) {
        expect(roundTrip(value), value);
        // Nested in a record and a list
        expect(roundTrip({'field': value}), {'field': value});
        expect(roundTrip([value]), [value]);
      }
    });
    test('escaped map content still encoded', () {
      var value = {r'$': SdbTimestamp(1, 2000)};
      var encoded = codec.encode(value);
      expect(encoded, {
        r'$': {
          r'$': {r'$Timestamp': '1970-01-01T00:00:01.000002Z'},
        },
      });
      expect(codec.decode<Object>(encoded), value);
    });
    test('unknown type kept unescaped', () {
      // Key paths and indexes still find the field.
      for (var value in <Object>[
        {r'$id': 1},
        {'@other': 'text'},
        {r'$a': 1, r'$b': 2},
      ]) {
        expect(codec.encode(value), value);
        expect(roundTrip(value), value);
      }
    });
    test('raw data not written by the codec', () {
      // Before the escape, {'$': 'raw'} was stored as is.
      expect(codec.decode<Object>({r'$': 'raw'}), {r'$': 'raw'});
      expect(codec.decode<Object>({r'$': 1}), {r'$': 1});
    });
  });
}
