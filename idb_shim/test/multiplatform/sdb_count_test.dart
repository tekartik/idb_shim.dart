import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';

final testStore = SdbStoreRef<int, SdbModel>('test');
final testIndex = testStore.index<String>('name');

Future<void> main() async {
  group('sdb_count', () {
    late SdbDatabase db;

    setUp(() async {
      var dbName = 'sdb_count_test.db';
      await sdbFactoryMemory.deleteDatabase(dbName);
      db = await sdbFactoryMemory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              testStore.schema(indexes: [testIndex.schema(keyPath: 'name')]),
            ],
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await testStore.record(i).put(db, {'name': 'name_$i'});
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('store count with offset and limit', () async {
      expect(await testStore.count(db), 10);
      expect(await testStore.count(db, options: SdbFindOptions(offset: 3)), 7);
      // The limit caps the count.
      expect(await testStore.count(db, options: SdbFindOptions(limit: 4)), 4);
      expect(await testStore.count(db, options: SdbFindOptions(limit: 40)), 10);
      expect(
        await testStore.count(db, options: SdbFindOptions(offset: 3, limit: 4)),
        4,
      );
      expect(
        await testStore.count(db, options: SdbFindOptions(offset: 8, limit: 4)),
        2,
      );
    });

    test('index count with offset and limit', () async {
      expect(await testIndex.count(db), 10);
      expect(await testIndex.count(db, options: SdbFindOptions(offset: 3)), 7);
      expect(await testIndex.count(db, options: SdbFindOptions(limit: 4)), 4);
      expect(await testIndex.count(db, options: SdbFindOptions(limit: 40)), 10);
      expect(
        await testIndex.count(db, options: SdbFindOptions(offset: 8, limit: 4)),
        2,
      );
    });
  });
}
