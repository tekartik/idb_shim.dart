import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_boundary_impl.dart';
import 'package:idb_shim/src/sdb/sdb_key_path_utils.dart';
import 'package:idb_shim/src/sdb/sdb_utils.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  group('boundaries', () {
    test('idbKeyRangeFromBoundaries', () async {
      var keyRange = idbKeyRangeFromBoundaries(SdbBoundaries.values(1, 3));
      expect(keyRange.toString(), 'kr[1-3[');
      keyRange = idbKeyRangeFromBoundaries(
        SdbBoundaries.values((1, ''), (3, 'test'), includeLower: false),
      );
      expect(keyRange.toString(), 'kr][1, ]-[3, test][');
    });
  });
  test('keypath', () {
    expect(idbKeyPathFromAny('key'), 'key');
    expect(idbKeyPathFromAny(['key']), 'key');
    expect(idbKeyPathFromAny(SdbKeyPath.single('key')), 'key');
    expect(idbKeyPathFromAny(SdbKeyPath.multi(['key1', 'key2'])), [
      'key1',
      'key2',
    ]);
  });
  group('SdbFindOptions', () {
    test('toString()', () {
      var options = SdbFindOptions(
        limit: 10,
        descending: true,
        offset: 2,
        filter: SdbFilter.equals('field', 1),
      );
      expect(
        options.toString(),
        'SdbFindOptions(limit: 10, offset: 2, descending: true, filter: field == 1)',
      );
    });
    test('none', () {
      expect(sdbFindOptionsMerge(null), isNotNull);
      var options = SdbFindOptions(limit: 10, descending: true);
      expect(sdbFindOptionsMerge(options), same(options));
      expect(
        sdbFindOptionsMerge(options, limit: 5, descending: false, offset: 2),
        same(options),
      );
      options = sdbFindOptionsMerge(
        null,
        limit: 5,
        descending: false,
        offset: 2,
        filter: SdbFilter.equals('field', 1),
        boundaries: SdbBoundaries.values(1, 10),
      );
      expect(options.limit, 5);
      expect(options.descending, false);
      expect(options.offset, 2);
      expect(options.filter, isA<SdbFilter>());
      expect(options.boundaries, SdbBoundaries.values(1, 10));
    });
    test('sdbToIdbValue', () {
      expect(sdbToIdbValue(1), 1);
      expect(sdbToIdbValue(SdbTimestamp(1, 2000)), {
        r'$Timestamp': '1970-01-01T00:00:01.000002Z',
      });
      expect(
        idbToSdbValue<SdbTimestamp>({
          r'$Timestamp': '1970-01-01T00:00:01.000002Z',
        }),
        SdbTimestamp(1, 2000),
      );
      expect(
        idbToSdbValue<SdbTimestamp>({
          r'@Timestamp': '1970-01-01T00:00:01.000002Z',
        }),
        SdbTimestamp(1, 2000),
      );
    });
    test('sdbIsValidIndexKeyParam', () {
      expect(sdbIsValidIndexKeyParam(DateTime.now()), false);
      expect(sdbIsValidIndexKeyParam(SdbTimestamp.now()), true);
      expect(sdbIsValidIndexKeyParam(null), false);
      expect(sdbIsValidIndexKeyParam(''), true);
      expect(sdbIsValidIndexKeyParam('a'), true);
      expect(sdbIsValidIndexKeyParam(0), true);
    });
  });
}
