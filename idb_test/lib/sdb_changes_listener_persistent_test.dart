// basically same as the io runner but with extra output

import 'package:idb_shim/sdb.dart';

import 'idb_test_common.dart';
import 'sdb_test.dart';

void main() {
  defineSdbChangesListenerTests(sdbMemoryContext);
}

void defineIdbSdbChangesListenerTests(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);
  defineSdbChangesListenerTests(SdbTestContext(factory));
}

void defineSdbChangesListenerTests(SdbTestContext ctx) {
  var store = SdbStoreRef<int, int>('test');
  var storeDup = SdbStoreRef<int, int>('test_dup');
  var factory = ctx.factory;

  group('changes_listener_persistent', () {
    tearDown(() async {});
    test('simple_add', () async {
      var dbName = 'sdb_changes_listener_persistent_add.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [store.schema(autoIncrement: true), storeDup.schema()],
          ),
        ),
      );

      Future<void> onChanges(
        SdbTransaction txn,
        List<SdbRecordChange> changes,
      ) async {
        for (var change in changes) {
          await storeDup
              .record(change.ref.key as int)
              .put(txn, change.newValue as int);
        }
      }

      store.addOnChangesListener(
        db,
        onChanges,
        extraStoreNames: [storeDup.name],
      );
      expect(await storeDup.record(1).get(db), isNull);
      var key = await store.add(db, 2);
      //print('added key: $key');
      expect(await storeDup.record(key).getValue(db), 2);
      await db.close();
      db = await factory.openDatabase(dbName);
      expect(await storeDup.record(key).getValue(db), 2);
      await db.close();
    });
  });
}
