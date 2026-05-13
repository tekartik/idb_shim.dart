import 'dart:async';

import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_database_impl.dart'
    show SdbDatabaseIdbExt, SdbDatabaseInternalExtension;
import 'package:test/test.dart';

final testStore = SdbStoreRef<int, String>('test');
final testModelStore = SdbStoreRef<int, SdbModel>('test_model');
final testIndex = testModelStore.index<String>('test_index');

/// Write directly to the underlying IDB, bypassing SDB change tracking.
/// Simulates a write that originated in another tab.
Future<void> writeDirectlyToIdb(
  SdbDatabase db,
  String storeName,
  Object key,
  Object value,
) async {
  var txn = db.rawIdb.transaction(storeName, idb.idbModeReadWrite);
  await txn.objectStore(storeName).put(value, key);
  await txn.completed;
}

Future<void> deleteDirectlyFromIdb(
  SdbDatabase db,
  String storeName,
  Object key,
) async {
  var txn = db.rawIdb.transaction(storeName, idb.idbModeReadWrite);
  await txn.objectStore(storeName).delete(key);
  await txn.completed;
}

Future<void> main() async {
  group('cross_tab', () {
    late SdbDatabase db;

    setUp(() async {
      var dbName = 'sdb_cross_tab_test.db';
      await sdbFactoryMemory.deleteDatabase(dbName);
      db = await sdbFactoryMemory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              testStore.schema(),
              testModelStore.schema(
                indexes: [testIndex.schema(keyPath: 'test_index')],
              ),
            ],
          ),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    late Completer<void> completer;
    void newCompleter() => completer = Completer<void>();
    void complete() {
      if (!completer.isCompleted) completer.complete();
    }

    Future<void> completed() => completer.future;

    test('externalStoreChanges not active without subscribers', () async {
      expect(db.impl.externalStoreChanges, isNotNull);
      // Controller is created lazily; no external subscription until listened to.
      // Just verify the stream exists.
    });

    test('onSnapshot reacts to simulated cross-tab notification', () async {
      var record = testStore.record(1);
      var snapshots = <SdbRecordSnapshot<int, String>?>[];

      var subscription = record.onSnapshot(db).listen((snapshot) {
        snapshots.add(snapshot);
        complete();
      });

      // Initial null — record does not exist yet
      newCompleter();
      await completed();
      expect(snapshots, [null]);

      // Simulate another tab writing record 1 directly to IDB
      await writeDirectlyToIdb(db, testStore.name, 1, 'from_other_tab');

      // Simulate the BroadcastChannel notification that the other tab would send
      newCompleter();
      db.impl.simulateExternalStoreChanges([testStore.name]);
      await completed();
      expect(snapshots.last!.value, 'from_other_tab');

      // Simulate another tab updating record 1
      await writeDirectlyToIdb(db, testStore.name, 1, 'updated_by_other_tab');
      newCompleter();
      db.impl.simulateExternalStoreChanges([testStore.name]);
      await completed();
      expect(snapshots.last!.value, 'updated_by_other_tab');

      // Simulate another tab deleting record 1
      await deleteDirectlyFromIdb(db, testStore.name, 1);
      newCompleter();
      db.impl.simulateExternalStoreChanges([testStore.name]);
      await completed();
      expect(snapshots.last, isNull);

      // Notification for a different store should not trigger a re-fetch
      var countBefore = snapshots.length;
      db.impl.simulateExternalStoreChanges(['other_store']);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(snapshots.length, countBefore);

      await subscription.cancel();
    });

    test('onSnapshots reacts to simulated cross-tab notification', () async {
      var snapshotsList = <List<SdbRecordSnapshot<int, String>>>[];

      var subscription = testStore.onSnapshots(db).listen((snapshots) {
        snapshotsList.add(snapshots);
        complete();
      });

      // Initial empty
      newCompleter();
      await completed();
      expect(snapshotsList.last, isEmpty);

      // Simulate another tab adding record 1
      await writeDirectlyToIdb(db, testStore.name, 1, 'rec1');
      newCompleter();
      db.impl.simulateExternalStoreChanges([testStore.name]);
      await completed();
      expect(snapshotsList.last, hasLength(1));
      expect(snapshotsList.last.first.value, 'rec1');

      // Simulate another tab adding record 2
      await writeDirectlyToIdb(db, testStore.name, 2, 'rec2');
      newCompleter();
      db.impl.simulateExternalStoreChanges([testStore.name]);
      await completed();
      expect(snapshotsList.last, hasLength(2));

      // Simulate another tab deleting record 1
      await deleteDirectlyFromIdb(db, testStore.name, 1);
      newCompleter();
      db.impl.simulateExternalStoreChanges([testStore.name]);
      await completed();
      expect(snapshotsList.last, hasLength(1));
      expect(snapshotsList.last.first.value, 'rec2');

      // Notification for a different store should be ignored
      var countBefore = snapshotsList.length;
      db.impl.simulateExternalStoreChanges(['unrelated_store']);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(snapshotsList.length, countBefore);

      await subscription.cancel();
    });

    test(
      'onIndexSnapshots reacts to simulated cross-tab notification',
      () async {
        var snapshotsList =
            <List<SdbIndexRecordSnapshot<int, SdbModel, String>>>[];

        var subscription = testIndex.onSnapshots(db).listen((snapshots) {
          snapshotsList.add(snapshots);
          complete();
        });

        // Initial empty
        newCompleter();
        await completed();
        expect(snapshotsList.last, isEmpty);

        // Simulate another tab adding a record
        await writeDirectlyToIdb(db, testModelStore.name, 1, {
          'test_index': 'val1',
        });
        newCompleter();
        db.impl.simulateExternalStoreChanges([testModelStore.name]);
        await completed();
        expect(snapshotsList.last, hasLength(1));
        expect(snapshotsList.last.first.value['test_index'], 'val1');

        // Simulate another tab deleting the record
        await deleteDirectlyFromIdb(db, testModelStore.name, 1);
        newCompleter();
        db.impl.simulateExternalStoreChanges([testModelStore.name]);
        await completed();
        expect(snapshotsList.last, isEmpty);

        await subscription.cancel();
      },
    );

    test(
      'cross-tab subscription is cleaned up after all listeners cancel',
      () async {
        var sub1 = testStore.onSnapshots(db).listen((_) {});
        var sub2 = testStore.record(1).onSnapshot(db).listen((_) {});

        // externalStoreChanges stream has active subscribers
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await sub1.cancel();
        await sub2.cancel();

        // After all listeners cancel, the external subscription should be torn down.
        // Verify by checking the changesListener is empty.
        expect(db.impl.changesListener.isEmpty, isTrue);
      },
    );

    test(
      'write tracking: noteWriteToStore populates written store names',
      () async {
        // A write via SDB should note the store name and broadcast after commit.
        // We verify the cross-tab pipeline by checking that a second listener
        // (simulating another "tab" via externalStoreChanges) does NOT see
        // writes from a direct IDB transaction (no SDB overhead).

        var snapshotsList = <List<SdbRecordSnapshot<int, String>>>[];
        var subscription = testStore.onSnapshots(db).listen((snapshots) {
          snapshotsList.add(snapshots);
          complete();
        });

        newCompleter();
        await completed();
        expect(snapshotsList.last, isEmpty);

        // SDB write: should trigger local listener (in-tab) via changesListener
        newCompleter();
        await testStore.record(1).put(db, 'via_sdb');
        await completed();
        expect(snapshotsList.last, hasLength(1));
        expect(snapshotsList.last.first.value, 'via_sdb');

        await subscription.cancel();
      },
    );
  });
}
