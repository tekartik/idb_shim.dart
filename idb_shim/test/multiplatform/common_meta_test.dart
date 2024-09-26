library;

import '../idb_test_common.dart';

// auto-increment, no key path
final IdbObjectStoreMeta idbSimpleObjectStoreMeta =
    IdbObjectStoreMeta(testStoreName, null, true);

final IdbObjectStoreMeta idbObjectStoreMeta1 =
    IdbObjectStoreMeta('name', 'my_key', true);
final IdbObjectStoreMeta idbObjectStoreMeta1Same =
    IdbObjectStoreMeta('name', 'my_key', true);
final IdbObjectStoreMeta idbObjectStoreMeta2 =
    IdbObjectStoreMeta('name', 'my_key', false);
final IdbObjectStoreMeta idbObjectStoreMeta3 =
    IdbObjectStoreMeta('name', null, true);
final IdbObjectStoreMeta idbObjectStoreMeta4 =
    IdbObjectStoreMeta('other_name', 'my_key', true);
final IdbObjectStoreMeta idbObjectStoreMetaComposite =
    IdbObjectStoreMeta('composite', ['my', 'key'], false);
final List<IdbObjectStoreMeta> idbObjectStoreMetas = [
  idbObjectStoreMeta1,
  idbObjectStoreMeta2,
  idbObjectStoreMeta3,
];

IdbIndexMeta idbIndexMeta1 = IdbIndexMeta('name', 'my_key', true, true);
IdbIndexMeta idbIndexMeta1Same = IdbIndexMeta('name', 'my_key', true, true);
IdbIndexMeta idbIndexMeta2 = IdbIndexMeta('name', 'my_key', true, false);
IdbIndexMeta idbIndexMeta3 = IdbIndexMeta('name', 'my_key', false, true);
IdbIndexMeta idbIndexMeta4 = IdbIndexMeta('name', 'other_key', true, true);
IdbIndexMeta idbIndexMeta5 = IdbIndexMeta('other_name', 'my_key', true, true);
IdbIndexMeta idbIndexMeta6 =
    IdbIndexMeta('path_array', ['my_key', 'other_key'], true, false);

// Bad cannot bet array and multi-entry
IdbIndexMeta idbIndexMeta7 =
    IdbIndexMeta('path_array', ['my_key', 'other_key'], true, true);
final List<IdbIndexMeta> idbIndexMetas = [
  idbIndexMeta1,
  idbIndexMeta2,
  idbIndexMeta3,
  idbIndexMeta4,
  idbIndexMeta5,
  idbIndexMeta6
];

void main() => defineTests();

void defineTests() {
  group('meta', () {
    test('database', () {
      final meta1 = IdbDatabaseMeta(1);
      final meta2 = IdbDatabaseMeta(1);
      expect(meta1, meta2);
      final meta3 = IdbDatabaseMeta(2);
      expect(meta1, isNot(meta3));
    });

    void testStoreRoundTrip(IdbObjectStoreMeta meta) {
      var map = meta.toMap();
      final newMeta = IdbObjectStoreMeta.fromMap(map);
      expect(newMeta, meta);
    }

    test('store', () {
      expect(idbObjectStoreMeta1, idbObjectStoreMeta1Same);
      expect(idbObjectStoreMeta1, isNot(idbObjectStoreMeta2));
      expect(idbObjectStoreMeta1, isNot(idbObjectStoreMeta3));
      expect(idbObjectStoreMeta1, isNot(idbObjectStoreMeta4));
      testStoreRoundTrip(idbObjectStoreMeta1);
    });

    test('index', () {
      expect(idbIndexMeta1, idbIndexMeta1Same);
      expect(idbIndexMeta1, isNot(idbIndexMeta2));
      expect(idbIndexMeta1, isNot(idbIndexMeta3));
      expect(idbIndexMeta1, isNot(idbIndexMeta4));
      expect(idbIndexMeta1, isNot(idbIndexMeta5));
    });

    test('store with index', () {
      final meta1 = idbSimpleObjectStoreMeta.clone();
      meta1.putIndex(idbIndexMeta1);
      final meta2 = idbSimpleObjectStoreMeta.clone();
      meta2.putIndex(idbIndexMeta1);
      expect(meta1, meta2);
      final meta3 = idbSimpleObjectStoreMeta.clone();
      meta2.putIndex(idbIndexMeta2);
      expect(meta1, isNot(meta3));
      testStoreRoundTrip(meta1);
    });

    test('store with keyPath array', () {
      final meta = idbObjectStoreMetaComposite;
      expect(meta.toMap(), {
        'name': 'composite',
        'keyPath': ['my', 'key']
      });
      testStoreRoundTrip(meta);
    });
    test('store with three indecies', () {
      final meta = idbSimpleObjectStoreMeta.clone();
      meta.putIndex(IdbIndexMeta('index3', 'keyA', true, false));
      meta.putIndex(IdbIndexMeta('index1', 'keyB', true, true));
      meta.putIndex(IdbIndexMeta('index2', 'keyC', false, true));
      expect(meta.toMap(), {
        'name': 'test_store',
        'autoIncrement': true,
        'indecies': [
          {
            'name': 'index1',
            'keyPath': 'keyB',
            'unique': true,
            'multiEntry': true
          },
          {'name': 'index2', 'keyPath': 'keyC', 'multiEntry': true},
          {'name': 'index3', 'keyPath': 'keyA', 'unique': true}
        ]
      });
    });

    test('store with keyPath array index', () {
      final meta = idbSimpleObjectStoreMeta.clone();
      meta.putIndex(IdbIndexMeta('index3', ['keyA', 'keyB'], true, false));
      expect(meta.toMap(), {
        'name': 'test_store',
        'autoIncrement': true,
        'indecies': [
          {
            'name': 'index3',
            'keyPath': ['keyA', 'keyB'],
            'unique': true
          }
        ]
      });
      testStoreRoundTrip(meta);
    });

    test('store to/from map', () {
      final meta1 = idbSimpleObjectStoreMeta.clone();
      meta1.putIndex(idbIndexMeta1);
      testStoreRoundTrip(meta1);
    });

    test('null transaction', () {
      final meta1 = IdbDatabaseMeta(1);
      meta1.transaction(null, idbModeReadWrite);
    });
  });
}
