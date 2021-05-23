import 'idb_test_common.dart';

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
final List<IdbObjectStoreMeta> idbObjectStoreMetas = [
  idbObjectStoreMeta1,
  idbObjectStoreMeta2,
  idbObjectStoreMeta3
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
