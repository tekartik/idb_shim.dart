import 'package:idb_shim/sdb.dart';
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
}
