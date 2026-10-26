library;

import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';

void main() {
  group('native_value_memory', () {
    test('idb put rejected', () async {
      var storeName = 'test';
      var db = await newIdbFactoryMemory().open(
        'native_value_memory.db',
        version: 1,
        onUpgradeNeeded: (event) {
          event.database.createObjectStore(storeName);
        },
      );
      var txn = db.transaction(storeName, idbModeReadWrite);
      var store = txn.objectStore(storeName);
      await expectLater(
        () async => await store.put(IdbNativeValue(Object()), 'key'),
        throwsA(isA<ArgumentError>()),
      );
      try {
        await txn.completed;
      } catch (_) {}
      db.close();
    });
    test('sdb put rejected', () async {
      var store = SdbStoreRef<String, SdbModel>('test');
      var db = await newSdbFactoryMemory().openDatabase(
        'native_value_memory.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [store.schema()]),
        ),
      );
      await expectLater(
        () async => await store.record('key').put(db, {
          'value': SdbNativeValue(Object()),
        }),
        // The transaction abort error hides the ArgumentError.
        throwsA(anything),
      );
      await db.close();
    });
    test('toString', () {
      expect(IdbNativeValue('value').toString(), 'IdbNativeValue(value)');
    });
  });
}
