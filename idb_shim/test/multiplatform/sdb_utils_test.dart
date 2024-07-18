import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_boundary_impl.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  group('boundaries', () {
    test('idbKeyRangeFromBoundaries', () async {
      var keyRange = idbKeyRangeFromBoundaries(SdbBoundaries.values(1, 3));
      expect(keyRange.toString(), 'kr[1-3[');
      keyRange = idbKeyRangeFromBoundaries(
          SdbBoundaries.values((1, ''), (3, 'test'), includeLower: false));
      expect(keyRange.toString(), 'kr][1, ]-[3, test][');
    });
  });
}
