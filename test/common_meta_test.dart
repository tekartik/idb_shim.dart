library idb_shim.common_meta_test;

import 'package:idb_shim/src/common/common_meta.dart';
import 'idb_test_common.dart';

// auto-increment, no key path
final IdbObjectStoreMeta idbSimpleObjectStoreMeta =
    new IdbObjectStoreMeta(STORE_NAME, null, true);

final IdbObjectStoreMeta idbObjectStoreMeta1 =
    new IdbObjectStoreMeta("name", "my_key", true);
final IdbObjectStoreMeta idbObjectStoreMeta1Same =
    new IdbObjectStoreMeta("name", "my_key", true);
final IdbObjectStoreMeta idbObjectStoreMeta2 =
    new IdbObjectStoreMeta("name", "my_key", false);
final IdbObjectStoreMeta idbObjectStoreMeta3 =
    new IdbObjectStoreMeta("name", null, true);
final IdbObjectStoreMeta idbObjectStoreMeta4 =
    new IdbObjectStoreMeta("other_name", "my_key", true);
final List<IdbObjectStoreMeta> idbObjectStoreMetas = [
  idbObjectStoreMeta1,
  idbObjectStoreMeta2,
  idbObjectStoreMeta3
];

IdbIndexMeta idbIndexMeta1 = new IdbIndexMeta("name", "my_key", true, true);
IdbIndexMeta idbIndexMeta1Same = new IdbIndexMeta("name", "my_key", true, true);
IdbIndexMeta idbIndexMeta2 = new IdbIndexMeta("name", "my_key", true, false);
IdbIndexMeta idbIndexMeta3 = new IdbIndexMeta("name", "my_key", false, true);
IdbIndexMeta idbIndexMeta4 = new IdbIndexMeta("name", "other_key", true, true);
IdbIndexMeta idbIndexMeta5 =
    new IdbIndexMeta("other_name", "my_key", true, true);
final List<IdbIndexMeta> idbIndexMetas = [
  idbIndexMeta1,
  idbIndexMeta2,
  idbIndexMeta3,
  idbIndexMeta4,
  idbIndexMeta5
];
void main() => defineTests();

void defineTests() {
  group('meta', () {
    test('database', () {
      IdbDatabaseMeta meta1 = new IdbDatabaseMeta(1);
      IdbDatabaseMeta meta2 = new IdbDatabaseMeta(1);
      expect(meta1, meta2);
      IdbDatabaseMeta meta3 = new IdbDatabaseMeta(2);
      expect(meta1, isNot(meta3));
    });

    test('store', () {
      expect(idbObjectStoreMeta1, idbObjectStoreMeta1Same);
      expect(idbObjectStoreMeta1, isNot(idbObjectStoreMeta2));
      expect(idbObjectStoreMeta1, isNot(idbObjectStoreMeta3));
      expect(idbObjectStoreMeta1, isNot(idbObjectStoreMeta4));
    });

    test('index', () {
      expect(idbIndexMeta1, idbIndexMeta1Same);
      expect(idbIndexMeta1, isNot(idbIndexMeta2));
      expect(idbIndexMeta1, isNot(idbIndexMeta3));
      expect(idbIndexMeta1, isNot(idbIndexMeta4));
      expect(idbIndexMeta1, isNot(idbIndexMeta5));
    });

    test('store with index', () {
      IdbObjectStoreMeta meta1 = idbSimpleObjectStoreMeta.clone();
      meta1.addIndex(idbIndexMeta1);
      IdbObjectStoreMeta meta2 = idbSimpleObjectStoreMeta.clone();
      meta2.addIndex(idbIndexMeta1);
      expect(meta1, meta2);
      IdbObjectStoreMeta meta3 = idbSimpleObjectStoreMeta.clone();
      meta2.addIndex(idbIndexMeta2);
      expect(meta1, isNot(meta3));
    });

    testStoreRoundTrip(IdbObjectStoreMeta meta) {
      Map map = meta.toMap();
      IdbObjectStoreMeta newMeta = new IdbObjectStoreMeta.fromMap(map);
      expect(newMeta, meta);
    }

    test('store to/from map', () {
      IdbObjectStoreMeta meta1 = idbSimpleObjectStoreMeta.clone();
      meta1.addIndex(idbIndexMeta1);
      testStoreRoundTrip(meta1);
    });
  });
}
