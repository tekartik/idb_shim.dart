import 'dart:async';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_database_impl.dart'
    show SdbDatabaseInternalExtension;
import 'package:test/test.dart';

final testStore = SdbStoreRef<int, String>('test');
final testModelStore = SdbStoreRef<int, SdbModel>('test_model');
final testIndex = testModelStore.index<String>('test_index');
Future<void> main() async {
  group('track_changes', () {
    late SdbDatabase db;

    setUp(() async {
      db = await sdbFactoryMemory.openDatabase(
        'test',
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

    late Completer completer;
    void newCompleter() {
      completer = Completer();
    }

    void complete() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    Future<void> completed() => completer.future;

    test('onSnapshot', () async {
      var record = testStore.record(1);

      var snapshots = <SdbRecordSnapshot<int, String>?>[];
      var subscription = record.onSnapshot(db).listen((snapshot) {
        snapshots.add(snapshot);
        complete();
      });

      // Initial null
      newCompleter();
      await completed();
      expect(snapshots, [null]);

      // Put 1
      newCompleter();
      await record.put(db, 'text1');
      await completed();
      expect(snapshots.last!.value, 'text1');

      // Put 2
      newCompleter();
      await record.put(db, 'text2');
      await completed();
      expect(snapshots.last!.value, 'text2');

      // Delete
      newCompleter();
      await record.delete(db);
      await completed();
      expect(snapshots.last, null);

      expect(db.impl.changesListener.isEmpty, isFalse);
      await subscription.cancel();
      expect(db.impl.changesListener.isEmpty, isTrue);
    });

    test('onSnapshots', () async {
      var snapshotsList = <List<SdbRecordSnapshot<int, String>>>[];
      var subscription = testStore.onSnapshots(db).listen((snapshots) {
        snapshotsList.add(snapshots);
        complete();
      });

      // Initial empty
      newCompleter();
      await completed();
      expect(snapshotsList.last, isEmpty);

      // Add 1
      newCompleter();
      await testStore.record(1).put(db, 'text1');
      await completed();
      expect(snapshotsList.last, hasLength(1));
      expect(snapshotsList.last.first.value, 'text1');

      // Add 2
      newCompleter();
      await testStore.record(2).put(db, 'text2');
      await completed();
      expect(snapshotsList.last, hasLength(2));
      expect(snapshotsList.last[1].value, 'text2');

      // Update 1
      newCompleter();
      await testStore.record(1).put(db, 'text1_updated');
      await completed();
      expect(snapshotsList.last.first.value, 'text1_updated');

      // Delete 2
      newCompleter();
      await testStore.record(2).delete(db);
      await completed();
      expect(snapshotsList.last, hasLength(1));

      expect(db.impl.changesListener.isEmpty, isFalse);
      await subscription.cancel();
      expect(db.impl.changesListener.isEmpty, isTrue);
    });

    test('onIndexSnapshot', () async {
      var indexRecord = testIndex.record('text1');

      var snapshots = <SdbIndexRecordSnapshot<int, SdbModel, String>?>[];
      var subscription = indexRecord.onSnapshot(db).listen((snapshot) {
        snapshots.add(snapshot);
        complete();
      });

      // Initial null
      newCompleter();
      await completed();
      expect(snapshots, [null]);

      // Put 1
      newCompleter();
      await testModelStore.record(1).put(db, {'test_index': 'text1'});
      await completed();
      expect(snapshots.last!.value['test_index'], 'text1');
      expect(snapshots.last!.key, 1);

      // Update 1 to something else
      newCompleter();
      await testModelStore.record(1).put(db, {'test_index': 'text2'});
      await completed();
      expect(snapshots.last, null);

      // Delete 1
      newCompleter();
      await testModelStore.record(1).delete(db);
      await completed();
      expect(snapshots.last, null);

      expect(db.impl.changesListener.isEmpty, isFalse);
      await subscription.cancel();
      expect(db.impl.changesListener.isEmpty, isTrue);
    });

    test('onIndexSnapshots', () async {
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

      // Add 1 matching index
      newCompleter();
      await testModelStore.record(1).put(db, {'test_index': 'text1'});
      await completed();
      expect(snapshotsList.last, hasLength(1));
      expect(snapshotsList.last.first.value['test_index'], 'text1');

      // Add 2 matching index
      newCompleter();
      await testModelStore.record(2).put(db, {'test_index': 'text2'});
      await completed();
      expect(snapshotsList.last, hasLength(2));

      // Update 1 to not match (index still tracks all records in this case, but we check values)
      newCompleter();
      await testModelStore.record(1).put(db, {'test_index': 'text1_updated'});
      await completed();
      expect(
        snapshotsList.last.any((s) => s.value['test_index'] == 'text1_updated'),
        isTrue,
      );

      // Delete 2
      newCompleter();
      await testModelStore.record(2).delete(db);
      await completed();
      expect(snapshotsList.last, hasLength(1));

      expect(db.impl.changesListener.isEmpty, isFalse);
      await subscription.cancel();
      expect(db.impl.changesListener.isEmpty, isTrue);
    });
  });
}
