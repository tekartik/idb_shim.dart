import 'package:idb_shim/sdb.dart';
import 'package:idb_test/sdb_test.dart';

import 'idb_test_common.dart';

void main() {
  idbSchemaSdbTest(idbMemoryContext);
}

var testStore1 = SdbStoreRef<int, SdbModel>('store1');
var testIndex1 = testStore1.index<int>('index1'); // On field 'field1'
final testSchemaIndex1 = testIndex1.schema(keyPath: 'field1');
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
        schema: SdbDatabaseSchema(stores: [testStore.schema()]),
      );
      expect(
        await db.readSchemaDef(),
        equals(
          SdbDatabaseSchemaDef(
            stores: [SdbStoreSchemaDef(name: testStore.name)],
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
              testStore.schema(indexes: [testSchemaIndex1]),
            ],
          ),
        );
      }, throwsA(isA<StateError>()));

      db = await factory.openDatabase(
        dbName,
        version: 2,
        schema: SdbDatabaseSchema(
          stores: [
            testStore.schema(indexes: [testSchemaIndex1]),
          ],
        ),
      );
      expect((await db.readSchemaDef()).toDebugMap(), {
        'stores': {
          'test': {
            'indexes': {
              'index1': {'keyPath': 'field1'},
            },
          },
        },
      });
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
