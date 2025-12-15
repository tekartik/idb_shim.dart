import 'package:idb_shim/sdb.dart';
import 'package:idb_test/sdb_test.dart';

import 'idb_test_common.dart';

void main() {
  idbSchemaSdbTest(idbMemoryContext);
}

var testStore1 = SdbStoreRef<int, SdbModel>('store1');
var testStore1Schema = testStore1.schema(autoIncrement: true);
var testIndex1 = testStore1.index<int>('index1'); // On field 'field1'
final testSchemaIndex1 = testIndex1.schema(keyPath: 'field1', unique: true);
final testSchemaIndex1bis = testIndex1.schema(keyPath: 'field2');

void idbSchemaSdbTest(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);
  schemaSdbTest(SdbTestContext(factory));
}

/// Simple SDB test
void schemaSdbTest(SdbTestContext ctx) {
  var factory = ctx.factory;

  group('sdb_schema', () {
    test('migration', () async {
      var dbName = 'sdb_schema_test.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(
        dbName,
        version: 1,
        schema: SdbDatabaseSchema(stores: [testStore1Schema]),
      );
      expect(
        await db.readSchemaDef(),
        equals(
          SdbDatabaseSchemaDef(
            stores: [
              SdbStoreSchemaDef(name: testStore1.name, autoIncrement: true),
            ],
          ),
        ),
      );
      await db.close();

      await expectLater(() async {
        await factory.openDatabase(
          dbName,
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              testStore1.schema(
                autoIncrement: true,
                indexes: [testSchemaIndex1],
              ),
            ],
          ),
        );
      }, throwsA(isA<StateError>()));

      db = await factory.openDatabase(
        dbName,
        version: 2,
        schema: SdbDatabaseSchema(
          stores: [
            testStore1.schema(autoIncrement: true, indexes: [testSchemaIndex1]),
          ],
        ),
      );
      expect((await db.readSchemaDef()).toDebugMap(), {
        'stores': {
          'store1': {
            'autoIncrement': true,
            'indexes': {
              'index1': {'keyPath': 'field1', 'unique': true},
            },
          },
        },
      });
      var key1 = await testStore1.add(db, {'field1': 1});
      expect(key1, 1);
      var key2 = await testStore1.add(db, {'field1': 2});
      expect(key2, 2);
      // ignore: dead_code
      try {
        await testStore1.add(db, {'field1': 1});
        fail('Should fail unique index');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
      }
      var key4 = await testStore1.add(db, {'field1': 4});
      expect(key4, 3);

      await db.close();
      await expectLater(() async {
        await factory.openDatabase(
          dbName,
          schema: SdbDatabaseSchema(
            stores: [
              testStore.schema(indexes: [testSchemaIndex1bis]),
            ],
          ),
        );
      }, throwsA(isA<StateError>()));
      //await db.close();
    });
  });
}
